import base64
import binascii
import hashlib
import hmac
import io
import json
import secrets
import sqlite3
import threading
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import cbor2
from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import ExtensionOID, ObjectIdentifier


APPLE_NONCE_EXTENSION_OID = ObjectIdentifier("1.2.840.113635.100.8.2")
ATTESTED_CREDENTIAL_DATA_FLAG = 0x40
EXTENSION_DATA_FLAG = 0x80
PRODUCTION_AAGUID = b"appattest" + (b"\x00" * 7)
DEVELOPMENT_AAGUID = b"appattestdevelop"


class AppAttestError(ValueError):
    pass


@dataclass(frozen=True)
class Challenge:
    identifier: str
    value: bytes
    purpose: str
    expires_at: float


@dataclass(frozen=True)
class AuthenticatorData:
    rp_id_hash: bytes
    flags: int
    counter: int
    aaguid: bytes | None
    credential_id: bytes | None
    extensions: dict


@dataclass(frozen=True)
class AttestedKey:
    key_id: str
    public_key_pem: bytes
    receipt: bytes
    counter: int
    environment: str
    validation_category: int | None
    bundle_version: str | None


class ChallengeStore:
    def __init__(self, ttl_seconds, max_outstanding, clock):
        self._ttl_seconds = ttl_seconds
        self._max_outstanding = max_outstanding
        self._clock = clock
        self._challenges = {}
        self._lock = threading.Lock()

    def issue(self, purpose):
        if purpose not in ("attestation", "assertion"):
            raise AppAttestError("Unsupported challenge purpose")

        now = self._clock()
        with self._lock:
            self._prune(now)
            if len(self._challenges) >= self._max_outstanding:
                raise AppAttestError("Too many outstanding challenges")

            challenge = Challenge(
                identifier=secrets.token_urlsafe(24),
                value=secrets.token_bytes(32),
                purpose=purpose,
                expires_at=now + self._ttl_seconds,
            )
            self._challenges[challenge.identifier] = challenge
            return challenge

    def consume(self, identifier, purpose):
        now = self._clock()
        with self._lock:
            self._prune(now)
            challenge = self._challenges.pop(identifier, None)

        if challenge is None:
            raise AppAttestError("Unknown or expired challenge")
        if challenge.purpose != purpose:
            raise AppAttestError("Challenge purpose mismatch")
        if challenge.expires_at <= now:
            raise AppAttestError("Challenge expired")
        return challenge.value

    def _prune(self, now):
        for identifier, challenge in list(self._challenges.items()):
            if challenge.expires_at <= now:
                del self._challenges[identifier]


class AppAttestStore:
    def __init__(self, database_path, clock):
        self._database_path = database_path
        self._clock = clock

    def initialize(self):
        parent = self._database_path.parent
        if not parent.exists():
            parent.mkdir(parents=True, exist_ok=True)

        with closing(self._connect()) as connection, connection:
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS app_attest_keys (
                    key_id TEXT PRIMARY KEY,
                    public_key_pem BLOB NOT NULL,
                    receipt BLOB NOT NULL,
                    counter INTEGER NOT NULL,
                    environment TEXT NOT NULL,
                    validation_category INTEGER,
                    bundle_version TEXT,
                    created_at INTEGER NOT NULL,
                    updated_at INTEGER NOT NULL
                )
                """
            )
        if self._database_path.exists():
            self._database_path.chmod(0o600)

    def register(self, attested_key):
        now = int(self._clock())
        with closing(self._connect()) as connection, connection:
            existing = connection.execute(
                "SELECT public_key_pem FROM app_attest_keys WHERE key_id = ?",
                (attested_key.key_id,),
            ).fetchone()
            if existing is not None:
                if not hmac.compare_digest(existing[0], attested_key.public_key_pem):
                    raise AppAttestError("Key identifier is already registered")
                return

            connection.execute(
                """
                INSERT INTO app_attest_keys (
                    key_id,
                    public_key_pem,
                    receipt,
                    counter,
                    environment,
                    validation_category,
                    bundle_version,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    attested_key.key_id,
                    attested_key.public_key_pem,
                    attested_key.receipt,
                    attested_key.counter,
                    attested_key.environment,
                    attested_key.validation_category,
                    attested_key.bundle_version,
                    now,
                    now,
                ),
            )

    def load(self, key_id):
        with closing(self._connect()) as connection, connection:
            row = connection.execute(
                """
                SELECT
                    key_id,
                    public_key_pem,
                    receipt,
                    counter,
                    environment,
                    validation_category,
                    bundle_version
                FROM app_attest_keys
                WHERE key_id = ?
                """,
                (key_id,),
            ).fetchone()
        if row is None:
            raise AppAttestError("Unknown App Attest key")
        return AttestedKey(*row)

    def advance_counter(self, key_id, previous_counter, next_counter):
        with closing(self._connect()) as connection, connection:
            result = connection.execute(
                """
                UPDATE app_attest_keys
                SET counter = ?, updated_at = ?
                WHERE key_id = ? AND counter = ?
                """,
                (next_counter, int(self._clock()), key_id, previous_counter),
            )
        if result.rowcount != 1:
            raise AppAttestError("Assertion counter replay detected")

    def _connect(self):
        connection = sqlite3.connect(self._database_path, timeout=10)
        connection.execute("PRAGMA journal_mode = WAL")
        connection.execute("PRAGMA busy_timeout = 10000")
        return connection


class AppAttestVerifier:
    def __init__(
        self,
        app_id,
        environment,
        allowed_categories,
        bundle_version,
        root_certificate_path,
        challenge_store,
        key_store,
    ):
        self._app_id = app_id
        self._environment = environment
        self._allowed_categories = frozenset(allowed_categories)
        self._bundle_version = bundle_version
        self._root_certificate_path = root_certificate_path
        self._challenge_store = challenge_store
        self._key_store = key_store
        self._root_certificate = None

    def initialize(self):
        if self._environment not in ("development", "production"):
            raise AppAttestError("Invalid App Attest environment")
        if not self._app_id.strip():
            raise AppAttestError("App Attest App ID is required")
        if not self._root_certificate_path.exists():
            raise AppAttestError("Apple App Attestation root certificate is missing")

        self._root_certificate = x509.load_pem_x509_certificate(
            self._root_certificate_path.read_bytes()
        )
        self._key_store.initialize()

    def issue_challenge(self, purpose):
        return self._challenge_store.issue(purpose)

    def register_key(self, challenge_id, key_id, attestation_object):
        challenge = self._challenge_store.consume(challenge_id, "attestation")
        self._key_store.register(
            self._verify_attestation(key_id, attestation_object, challenge)
        )

    def verify_assertion(
        self,
        challenge_id,
        key_id,
        assertion_object,
        client_data,
        request_body,
        method,
        path,
    ):
        challenge = self._challenge_store.consume(challenge_id, "assertion")
        self._verify_client_data(client_data, challenge, request_body, method, path)
        attested_key = self._key_store.load(key_id)
        if attested_key.environment != self._environment:
            raise AppAttestError("Attested key environment mismatch")
        assertion = _decode_cbor(assertion_object, "assertion")
        if not isinstance(assertion, dict):
            raise AppAttestError("Invalid assertion structure")

        signature = assertion.get("signature")
        authenticator_bytes = assertion.get("authenticatorData")
        if not isinstance(signature, bytes) or not isinstance(authenticator_bytes, bytes):
            raise AppAttestError("Invalid assertion fields")

        authenticator = _parse_authenticator_data(
            authenticator_bytes,
            expects_attested_credential=False,
        )
        if not hmac.compare_digest(
            authenticator.rp_id_hash,
            hashlib.sha256(self._app_id.encode("utf-8")).digest(),
        ):
            raise AppAttestError("Assertion App ID mismatch")
        if authenticator.counter <= attested_key.counter:
            raise AppAttestError("Assertion counter replay detected")

        public_key = serialization.load_pem_public_key(attested_key.public_key_pem)
        if not isinstance(public_key, ec.EllipticCurvePublicKey):
            raise AppAttestError("Unsupported attested public key")
        nonce = hashlib.sha256(
            authenticator_bytes + hashlib.sha256(client_data).digest()
        ).digest()
        try:
            public_key.verify(
                signature,
                nonce,
                ec.ECDSA(hashes.SHA256()),
            )
        except InvalidSignature as error:
            raise AppAttestError("Invalid App Attest assertion signature") from error

        self._verify_extensions(authenticator.extensions, attested_key)
        self._key_store.advance_counter(
            key_id,
            attested_key.counter,
            authenticator.counter,
        )

    def _verify_attestation(self, key_id, attestation_object, challenge):
        key_identifier = _decode_standard_base64(key_id, "key identifier")
        if len(key_identifier) != 32:
            raise AppAttestError("Invalid App Attest key identifier")

        attestation = _decode_cbor(attestation_object, "attestation")
        if not isinstance(attestation, dict) or attestation.get("fmt") != "apple-appattest":
            raise AppAttestError("Invalid App Attest format")

        statement = attestation.get("attStmt")
        authenticator_bytes = attestation.get("authData")
        if not isinstance(statement, dict) or not isinstance(authenticator_bytes, bytes):
            raise AppAttestError("Invalid attestation structure")
        certificate_chain = statement.get("x5c")
        receipt = statement.get("receipt")
        if (
            not isinstance(certificate_chain, list)
            or len(certificate_chain) < 2
            or not all(isinstance(item, bytes) for item in certificate_chain)
            or not isinstance(receipt, bytes)
            or not receipt
        ):
            raise AppAttestError("Invalid attestation statement")

        credential_certificate = x509.load_der_x509_certificate(certificate_chain[0])
        intermediate_certificate = x509.load_der_x509_certificate(certificate_chain[1])
        self._verify_certificate_chain(
            credential_certificate,
            intermediate_certificate,
        )

        nonce = hashlib.sha256(
            authenticator_bytes + hashlib.sha256(challenge).digest()
        ).digest()
        try:
            nonce_extension = credential_certificate.extensions.get_extension_for_oid(
                APPLE_NONCE_EXTENSION_OID
            )
        except x509.ExtensionNotFound as error:
            raise AppAttestError("Attestation nonce extension is missing") from error
        if not hmac.compare_digest(
            _decode_der_octet_string_sequence(nonce_extension.value.value),
            nonce,
        ):
            raise AppAttestError("Attestation challenge mismatch")

        public_key = credential_certificate.public_key()
        if (
            not isinstance(public_key, ec.EllipticCurvePublicKey)
            or not isinstance(public_key.curve, ec.SECP256R1)
        ):
            raise AppAttestError("Unsupported App Attest public key")
        public_key_bytes = public_key.public_bytes(
            serialization.Encoding.X962,
            serialization.PublicFormat.UncompressedPoint,
        )
        if not hmac.compare_digest(hashlib.sha256(public_key_bytes).digest(), key_identifier):
            raise AppAttestError("Attestation key identifier mismatch")

        authenticator = _parse_authenticator_data(
            authenticator_bytes,
            expects_attested_credential=True,
        )
        if not hmac.compare_digest(
            authenticator.rp_id_hash,
            hashlib.sha256(self._app_id.encode("utf-8")).digest(),
        ):
            raise AppAttestError("Attestation App ID mismatch")
        if authenticator.counter != 0:
            raise AppAttestError("Initial App Attest counter must be zero")
        if not hmac.compare_digest(authenticator.credential_id, key_identifier):
            raise AppAttestError("Attestation credential identifier mismatch")

        expected_aaguid = (
            PRODUCTION_AAGUID
            if self._environment == "production"
            else DEVELOPMENT_AAGUID
        )
        if not hmac.compare_digest(authenticator.aaguid, expected_aaguid):
            raise AppAttestError("App Attest environment mismatch")

        validation_category, bundle_version = self._validated_extension_values(
            authenticator.extensions
        )
        return AttestedKey(
            key_id=key_id,
            public_key_pem=public_key.public_bytes(
                serialization.Encoding.PEM,
                serialization.PublicFormat.SubjectPublicKeyInfo,
            ),
            receipt=receipt,
            counter=0,
            environment=self._environment,
            validation_category=validation_category,
            bundle_version=bundle_version,
        )

    def _verify_certificate_chain(self, credential, intermediate):
        if self._root_certificate is None:
            raise AppAttestError("App Attest verifier is not initialized")
        if credential.issuer != intermediate.subject:
            raise AppAttestError("Invalid App Attest credential issuer")
        if intermediate.issuer != self._root_certificate.subject:
            raise AppAttestError("Invalid App Attest intermediate issuer")

        now = datetime.now(timezone.utc)
        for certificate in (credential, intermediate, self._root_certificate):
            not_before = getattr(certificate, "not_valid_before_utc", None)
            not_after = getattr(certificate, "not_valid_after_utc", None)
            if not_before is None or not_after is None:
                not_before = certificate.not_valid_before.replace(tzinfo=timezone.utc)
                not_after = certificate.not_valid_after.replace(tzinfo=timezone.utc)
            if now < not_before or now > not_after:
                raise AppAttestError("Expired or not-yet-valid App Attest certificate")

        _verify_certificate_signature(credential, intermediate.public_key())
        _verify_certificate_signature(intermediate, self._root_certificate.public_key())
        try:
            credential_constraints = credential.extensions.get_extension_for_oid(
                ExtensionOID.BASIC_CONSTRAINTS
            ).value
            intermediate_constraints = intermediate.extensions.get_extension_for_oid(
                ExtensionOID.BASIC_CONSTRAINTS
            ).value
        except x509.ExtensionNotFound as error:
            raise AppAttestError("App Attest certificate constraints are missing") from error
        if credential_constraints.ca or not intermediate_constraints.ca:
            raise AppAttestError("Invalid App Attest certificate constraints")

    def _verify_client_data(self, client_data, challenge, body, method, path):
        if len(client_data) > 4096:
            raise AppAttestError("App Attest client data is too large")
        try:
            decoded = json.loads(client_data.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as error:
            raise AppAttestError("Invalid App Attest client data") from error
        if not isinstance(decoded, dict):
            raise AppAttestError("Invalid App Attest client data")

        expected_challenge = _encode_urlsafe_base64(challenge)
        expected_body_hash = _encode_urlsafe_base64(hashlib.sha256(body).digest())
        if not hmac.compare_digest(str(decoded.get("challenge", "")), expected_challenge):
            raise AppAttestError("Assertion challenge mismatch")
        if not hmac.compare_digest(str(decoded.get("bodySha256", "")), expected_body_hash):
            raise AppAttestError("Assertion request body mismatch")
        if decoded.get("method") != method or decoded.get("path") != path:
            raise AppAttestError("Assertion request target mismatch")

    def _verify_extensions(self, extensions, attested_key):
        validation_category, bundle_version = self._validated_extension_values(extensions)
        if (
            attested_key.validation_category is not None
            and validation_category != attested_key.validation_category
        ):
            raise AppAttestError("Assertion validation category mismatch")
        if (
            attested_key.bundle_version is not None
            and bundle_version != attested_key.bundle_version
        ):
            raise AppAttestError("Assertion bundle version mismatch")

    def _validated_extension_values(self, extensions):
        if not extensions:
            return None, None
        validation_category = extensions.get("apple_validation_category_01")
        bundle_version = extensions.get("apple_bundle_version_01")
        if not isinstance(validation_category, int) or isinstance(validation_category, bool):
            raise AppAttestError("Invalid App Attest validation category")
        if validation_category not in self._allowed_categories:
            raise AppAttestError("Disallowed App Attest validation category")
        if not isinstance(bundle_version, str) or bundle_version != self._bundle_version:
            raise AppAttestError("Unexpected App Attest bundle version")
        return validation_category, bundle_version


def _parse_authenticator_data(data, expects_attested_credential):
    if len(data) < 37:
        raise AppAttestError("Authenticator data is too short")

    flags = data[32]
    offset = 37
    aaguid = None
    credential_id = None
    if expects_attested_credential:
        if not flags & ATTESTED_CREDENTIAL_DATA_FLAG or len(data) < offset + 18:
            raise AppAttestError("Attested credential data is missing")
        aaguid = data[offset:offset + 16]
        credential_length = int.from_bytes(data[offset + 16:offset + 18], "big")
        offset += 18
        if credential_length != 32 or len(data) < offset + credential_length:
            raise AppAttestError("Invalid attested credential identifier")
        credential_id = data[offset:offset + credential_length]
        offset += credential_length
        offset = _consume_cbor_item(data, offset, "credential public key")
    extensions = {}
    if flags & EXTENSION_DATA_FLAG:
        extension_stream = io.BytesIO(data[offset:])
        try:
            extensions = cbor2.CBORDecoder(extension_stream).decode()
        except (cbor2.CBORDecodeError, EOFError, ValueError) as error:
            raise AppAttestError("Invalid authenticator extensions") from error
        offset += extension_stream.tell()
        if not isinstance(extensions, dict):
            raise AppAttestError("Invalid authenticator extensions")

    if offset != len(data):
        raise AppAttestError("Unexpected trailing authenticator data")
    return AuthenticatorData(
        rp_id_hash=data[:32],
        flags=flags,
        counter=int.from_bytes(data[33:37], "big"),
        aaguid=aaguid,
        credential_id=credential_id,
        extensions=extensions,
    )


def _consume_cbor_item(data, offset, label):
    stream = io.BytesIO(data[offset:])
    try:
        item = cbor2.CBORDecoder(stream).decode()
    except (cbor2.CBORDecodeError, EOFError, ValueError) as error:
        raise AppAttestError(f"Invalid {label}") from error
    if not isinstance(item, dict):
        raise AppAttestError(f"Invalid {label}")
    return offset + stream.tell()


def _decode_cbor(data, label):
    if len(data) > 100_000:
        raise AppAttestError(f"{label.capitalize()} is too large")
    stream = io.BytesIO(data)
    try:
        decoded = cbor2.CBORDecoder(stream).decode()
    except (cbor2.CBORDecodeError, EOFError, ValueError) as error:
        raise AppAttestError(f"Invalid {label} CBOR") from error
    if stream.tell() != len(data):
        raise AppAttestError(f"Unexpected trailing {label} data")
    return decoded


def _verify_certificate_signature(certificate, issuer_public_key):
    if not isinstance(issuer_public_key, ec.EllipticCurvePublicKey):
        raise AppAttestError("Unsupported App Attest certificate key")
    try:
        issuer_public_key.verify(
            certificate.signature,
            certificate.tbs_certificate_bytes,
            ec.ECDSA(certificate.signature_hash_algorithm),
        )
    except InvalidSignature as error:
        raise AppAttestError("Invalid App Attest certificate signature") from error


def _decode_der_octet_string_sequence(encoded):
    sequence, offset = _read_der_value(encoded, 0, 0x30)
    if offset != len(encoded):
        raise AppAttestError("Invalid App Attest nonce extension")

    context_specific, sequence_offset = _read_der_value(sequence, 0, 0xA1)
    if sequence_offset != len(sequence):
        raise AppAttestError("Invalid App Attest nonce extension")

    nonce, context_offset = _read_der_value(context_specific, 0, 0x04)
    if context_offset != len(context_specific):
        raise AppAttestError("Invalid App Attest nonce extension")
    if len(nonce) != 32:
        raise AppAttestError("Invalid App Attest nonce extension")
    return nonce


def _read_der_value(encoded, offset, expected_tag):
    if offset >= len(encoded) or encoded[offset] != expected_tag:
        raise AppAttestError("Invalid DER value")
    offset += 1
    if offset >= len(encoded):
        raise AppAttestError("Invalid DER length")

    first_length_byte = encoded[offset]
    offset += 1
    if first_length_byte < 0x80:
        length = first_length_byte
    else:
        length_byte_count = first_length_byte & 0x7F
        if length_byte_count == 0 or length_byte_count > 4:
            raise AppAttestError("Invalid DER length")
        if offset + length_byte_count > len(encoded):
            raise AppAttestError("Invalid DER length")
        length = int.from_bytes(encoded[offset:offset + length_byte_count], "big")
        offset += length_byte_count

    end = offset + length
    if end > len(encoded):
        raise AppAttestError("Invalid DER value length")
    return encoded[offset:end], end


def _decode_standard_base64(value, label):
    if not isinstance(value, str) or len(value) > 1024:
        raise AppAttestError(f"Invalid {label}")
    try:
        return base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        raise AppAttestError(f"Invalid {label}") from error


def _encode_urlsafe_base64(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")
