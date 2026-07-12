import base64
import hashlib
import json
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

import cbor2
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app_attest import (
    APPLE_NONCE_EXTENSION_OID,
    PRODUCTION_AAGUID,
    AppAttestError,
    AppAttestStore,
    AppAttestVerifier,
    ChallengeStore,
    _parse_authenticator_data,
)


APP_ID = "A2RM3XYB3K.com.teopateo.TeoPateo"


class AppAttestTests(unittest.TestCase):
    def test_challenges_are_single_use_and_expire(self):
        now = [100.0]
        store = ChallengeStore(30, 5, lambda: now[0])
        challenge = store.issue("assertion")

        self.assertEqual(
            store.consume(challenge.identifier, "assertion"),
            challenge.value,
        )
        with self.assertRaises(AppAttestError):
            store.consume(challenge.identifier, "assertion")

        expired = store.issue("attestation")
        now[0] = 131.0
        with self.assertRaises(AppAttestError):
            store.consume(expired.identifier, "attestation")

    def test_attestation_and_assertion_are_verified_end_to_end(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            fixture = AppAttestFixture(Path(temporary_directory))
            verifier = fixture.verifier()
            verifier.initialize()

            registration_challenge = verifier.issue_challenge("attestation")
            verifier.register_key(
                registration_challenge.identifier,
                fixture.key_id,
                fixture.attestation_object(registration_challenge.value),
            )

            body = b'{"messages":[{"role":"user","content":"Help"}]}'
            assertion_challenge = verifier.issue_challenge("assertion")
            client_data = fixture.client_data(assertion_challenge.value, body)
            verifier.verify_assertion(
                assertion_challenge.identifier,
                fixture.key_id,
                fixture.assertion_object(client_data, counter=1),
                client_data,
                body,
                "POST",
                "/v1/coach/reply",
            )

            with self.assertRaises(AppAttestError):
                verifier.verify_assertion(
                    assertion_challenge.identifier,
                    fixture.key_id,
                    fixture.assertion_object(client_data, counter=1),
                    client_data,
                    body,
                    "POST",
                    "/v1/coach/reply",
                )

    def test_assertion_is_bound_to_request_body_and_counter(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            fixture = AppAttestFixture(Path(temporary_directory))
            verifier = fixture.verifier()
            verifier.initialize()
            registration_challenge = verifier.issue_challenge("attestation")
            verifier.register_key(
                registration_challenge.identifier,
                fixture.key_id,
                fixture.attestation_object(registration_challenge.value),
            )

            signed_body = b'{"messages":[{"role":"user","content":"Signed"}]}'
            changed_body = b'{"messages":[{"role":"user","content":"Changed"}]}'
            body_challenge = verifier.issue_challenge("assertion")
            body_client_data = fixture.client_data(body_challenge.value, signed_body)
            with self.assertRaises(AppAttestError):
                verifier.verify_assertion(
                    body_challenge.identifier,
                    fixture.key_id,
                    fixture.assertion_object(body_client_data, counter=1),
                    body_client_data,
                    changed_body,
                    "POST",
                    "/v1/coach/reply",
                )

            first_challenge = verifier.issue_challenge("assertion")
            first_client_data = fixture.client_data(first_challenge.value, signed_body)
            verifier.verify_assertion(
                first_challenge.identifier,
                fixture.key_id,
                fixture.assertion_object(first_client_data, counter=1),
                first_client_data,
                signed_body,
                "POST",
                "/v1/coach/reply",
            )

            replay_challenge = verifier.issue_challenge("assertion")
            replay_client_data = fixture.client_data(replay_challenge.value, signed_body)
            with self.assertRaises(AppAttestError):
                verifier.verify_assertion(
                    replay_challenge.identifier,
                    fixture.key_id,
                    fixture.assertion_object(replay_client_data, counter=1),
                    replay_client_data,
                    signed_body,
                    "POST",
                    "/v1/coach/reply",
                )

    def test_checked_in_apple_root_certificate_is_the_app_attestation_root(self):
        certificate_path = Path(__file__).resolve().parent / "Apple_App_Attestation_Root_CA.pem"
        certificate = x509.load_pem_x509_certificate(certificate_path.read_bytes())

        self.assertIn(
            "Apple App Attestation Root CA",
            certificate.subject.rfc4514_string(),
        )
        not_valid_after = getattr(certificate, "not_valid_after_utc", None)
        if not_valid_after is None:
            not_valid_after = certificate.not_valid_after
        self.assertEqual(not_valid_after.year, 2045)

    def test_simplified_production_assertion_accepts_signed_attested_data_flag(self):
        authenticator_data = (
            hashlib.sha256(APP_ID.encode("utf-8")).digest()
            + bytes([0x40])
            + (1).to_bytes(4, "big")
        )

        parsed = _parse_authenticator_data(
            authenticator_data,
            expects_attested_credential=False,
        )

        self.assertEqual(parsed.counter, 1)
        self.assertEqual(parsed.extensions, {})


class AppAttestFixture:
    def __init__(self, directory):
        self.directory = directory
        self.now = [1_000.0]
        self.root_key = ec.generate_private_key(ec.SECP384R1())
        self.intermediate_key = ec.generate_private_key(ec.SECP384R1())
        self.credential_key = ec.generate_private_key(ec.SECP256R1())
        self.root_certificate = self._root_certificate()
        self.intermediate_certificate = self._intermediate_certificate()
        self.root_path = directory / "test-root.pem"
        self.root_path.write_bytes(
            self.root_certificate.public_bytes(serialization.Encoding.PEM)
        )
        public_key_bytes = self.credential_key.public_key().public_bytes(
            serialization.Encoding.X962,
            serialization.PublicFormat.UncompressedPoint,
        )
        self.key_identifier = hashlib.sha256(public_key_bytes).digest()
        self.key_id = base64.b64encode(self.key_identifier).decode("ascii")

    def verifier(self):
        return AppAttestVerifier(
            app_id=APP_ID,
            environment="production",
            allowed_categories={2, 4},
            bundle_version="1.0",
            root_certificate_path=self.root_path,
            challenge_store=ChallengeStore(300, 100, lambda: self.now[0]),
            key_store=AppAttestStore(
                self.directory / "app-attest.sqlite3",
                lambda: self.now[0],
            ),
        )

    def attestation_object(self, challenge):
        authenticator_data = self._attestation_authenticator_data()
        nonce = hashlib.sha256(
            authenticator_data + hashlib.sha256(challenge).digest()
        ).digest()
        credential_certificate = self._credential_certificate(nonce)
        return cbor2.dumps({
            "fmt": "apple-appattest",
            "attStmt": {
                "x5c": [
                    credential_certificate.public_bytes(serialization.Encoding.DER),
                    self.intermediate_certificate.public_bytes(serialization.Encoding.DER),
                ],
                "receipt": b"test-receipt",
            },
            "authData": authenticator_data,
        })

    def assertion_object(self, client_data, counter):
        authenticator_data = self._assertion_authenticator_data(counter)
        nonce = hashlib.sha256(
            authenticator_data + hashlib.sha256(client_data).digest()
        ).digest()
        signature = self.credential_key.sign(
            nonce,
            ec.ECDSA(hashes.SHA256()),
        )
        return cbor2.dumps({
            "signature": signature,
            "authenticatorData": authenticator_data,
        })

    def client_data(self, challenge, body):
        return json.dumps(
            {
                "bodySha256": urlsafe_base64(hashlib.sha256(body).digest()),
                "challenge": urlsafe_base64(challenge),
                "method": "POST",
                "path": "/v1/coach/reply",
            },
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")

    def _attestation_authenticator_data(self):
        public_numbers = self.credential_key.public_key().public_numbers()
        cose_key = cbor2.dumps({
            1: 2,
            3: -7,
            -1: 1,
            -2: public_numbers.x.to_bytes(32, "big"),
            -3: public_numbers.y.to_bytes(32, "big"),
        })
        return (
            hashlib.sha256(APP_ID.encode("utf-8")).digest()
            + bytes([0x40 | 0x80])
            + (0).to_bytes(4, "big")
            + PRODUCTION_AAGUID
            + len(self.key_identifier).to_bytes(2, "big")
            + self.key_identifier
            + cose_key
            + self._extensions()
        )

    def _assertion_authenticator_data(self, counter):
        return (
            hashlib.sha256(APP_ID.encode("utf-8")).digest()
            + bytes([0x80])
            + counter.to_bytes(4, "big")
            + self._extensions()
        )

    def _extensions(self):
        return cbor2.dumps({
            "apple_validation_category_01": 2,
            "apple_bundle_version_01": "1.0",
        })

    def _root_certificate(self):
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "Test App Attest Root")])
        return self._certificate_builder(name, name, self.root_key.public_key(), True).sign(
            self.root_key,
            hashes.SHA384(),
        )

    def _intermediate_certificate(self):
        subject = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "Test App Attest Intermediate")
        ])
        return self._certificate_builder(
            subject,
            self.root_certificate.subject,
            self.intermediate_key.public_key(),
            True,
        ).sign(self.root_key, hashes.SHA384())

    def _credential_certificate(self, nonce):
        subject = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, "Test App Attest Credential")
        ])
        nonce_extension = b"\x30\x24\xA1\x22\x04\x20" + nonce
        return self._certificate_builder(
            subject,
            self.intermediate_certificate.subject,
            self.credential_key.public_key(),
            False,
        ).add_extension(
            x509.UnrecognizedExtension(APPLE_NONCE_EXTENSION_OID, nonce_extension),
            critical=False,
        ).sign(self.intermediate_key, hashes.SHA384())

    def _certificate_builder(self, subject, issuer, public_key, is_ca):
        current = datetime.now(timezone.utc)
        return (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(public_key)
            .serial_number(x509.random_serial_number())
            .not_valid_before(current - timedelta(days=1))
            .not_valid_after(current + timedelta(days=30))
            .add_extension(x509.BasicConstraints(ca=is_ca, path_length=None), critical=True)
        )


def urlsafe_base64(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


if __name__ == "__main__":
    unittest.main()
