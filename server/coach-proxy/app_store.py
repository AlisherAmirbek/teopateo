"""Verified App Store subscription state for the Coach proxy.

The client only supplies Apple's signed StoreKit transaction (JWS).  This
module verifies that signature with Apple's certificate chain before storing
the minimum state needed to authorize coach access.  It deliberately doesn't
store a customer Apple ID, message content, or a raw access token.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import sqlite3
import time
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional

from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.signed_data_verifier import (
    SignedDataVerifier,
    VerificationException,
)
from cryptography import x509
from cryptography.hazmat.primitives import serialization


class AppStoreVerificationError(ValueError):
    """The supplied App Store signed data wasn't acceptable."""


class CoachAccessError(PermissionError):
    """A short-lived Coach access token cannot be used."""


@dataclass(frozen=True)
class VerifiedSubscriptionTransaction:
    original_transaction_id: str
    transaction_id: str
    product_id: str
    expires_at: int
    revocation_at: Optional[int]
    signed_at: int
    environment: str


@dataclass(frozen=True)
class VerifiedRenewalInfo:
    original_transaction_id: str
    product_id: Optional[str]
    grace_period_expires_at: Optional[int]
    auto_renew_status: Optional[int]
    is_in_billing_retry_period: Optional[bool]
    expiration_intent: Optional[int]
    signed_at: int


class AppStoreSubscriptionVerifier:
    """Verifies StoreKit and App Store Server Notification V2 JWS payloads."""

    def __init__(
        self,
        root_certificates: Iterable[bytes],
        bundle_id: str,
        allowed_product_ids: Iterable[str],
        allowed_environments: Iterable[str],
        app_apple_id: Optional[int],
        enable_online_checks: bool,
    ):
        self._bundle_id = bundle_id
        self._allowed_product_ids = frozenset(allowed_product_ids)
        self._allowed_environments = frozenset(allowed_environments)
        self._verifiers = {}
        root_certificates = list(root_certificates)

        if not root_certificates:
            raise ValueError("At least one App Store root certificate is required")
        if not self._bundle_id:
            raise ValueError("App Store bundle ID is required")
        if not self._allowed_product_ids:
            raise ValueError("At least one App Store product ID is required")

        for environment_name in self._allowed_environments:
            environment = _environment_from_name(environment_name)
            if environment not in (Environment.SANDBOX, Environment.PRODUCTION):
                raise ValueError("Only Sandbox and Production are supported")
            if environment == Environment.PRODUCTION and app_apple_id is None:
                raise ValueError("APP_STORE_APPLE_ID is required for Production")
            self._verifiers[environment_name] = SignedDataVerifier(
                root_certificates,
                enable_online_checks,
                environment,
                self._bundle_id,
                app_apple_id if environment == Environment.PRODUCTION else None,
            )

    def verify_client_transaction(self, signed_transaction: str) -> VerifiedSubscriptionTransaction:
        verifier = self._verifier_for(signed_transaction)
        try:
            transaction = verifier.verify_and_decode_signed_transaction(signed_transaction)
        except VerificationException as error:
            raise AppStoreVerificationError("Invalid StoreKit transaction") from error
        return self._transaction_from_payload(transaction)

    def verify_notification(
        self, signed_payload: str
    ) -> tuple[str, str, Optional[VerifiedSubscriptionTransaction], Optional[VerifiedRenewalInfo]]:
        verifier = self._verifier_for(signed_payload)
        try:
            notification = verifier.verify_and_decode_notification(signed_payload)
        except VerificationException as error:
            raise AppStoreVerificationError("Invalid App Store notification") from error

        notification_uuid = str(notification.notificationUUID or "").strip()
        notification_type = str(notification.rawNotificationType or "").strip()
        if not notification_uuid or not notification_type:
            raise AppStoreVerificationError("Notification identity is missing")

        data = notification.data
        if data is None:
            # Apple can send a signed TEST notification without transaction data.
            return notification_uuid, notification_type, None, None

        try:
            transaction_payload = verifier.verify_and_decode_signed_transaction(
                data.signedTransactionInfo
            )
        except (VerificationException, TypeError) as error:
            raise AppStoreVerificationError("Invalid notification transaction") from error
        transaction = self._transaction_from_payload(transaction_payload)

        renewal = None
        if data.signedRenewalInfo:
            try:
                renewal_payload = verifier.verify_and_decode_renewal_info(
                    data.signedRenewalInfo
                )
            except VerificationException as error:
                raise AppStoreVerificationError("Invalid notification renewal info") from error
            original_transaction_id = str(
                renewal_payload.originalTransactionId or ""
            ).strip()
            if original_transaction_id != transaction.original_transaction_id:
                raise AppStoreVerificationError("Notification subscription identities differ")
            renewal = VerifiedRenewalInfo(
                original_transaction_id=original_transaction_id,
                product_id=_optional_text(renewal_payload.productId),
                grace_period_expires_at=_milliseconds_to_seconds(
                    renewal_payload.gracePeriodExpiresDate
                ),
                auto_renew_status=_optional_int(renewal_payload.rawAutoRenewStatus),
                is_in_billing_retry_period=renewal_payload.isInBillingRetryPeriod,
                expiration_intent=_optional_int(renewal_payload.rawExpirationIntent),
                signed_at=_milliseconds_to_seconds(renewal_payload.signedDate) or int(time.time()),
            )

        return notification_uuid, notification_type, transaction, renewal

    def _verifier_for(self, signed_jws: str) -> SignedDataVerifier:
        payload = _unverified_jws_payload(signed_jws)
        environment_name = _optional_text(payload.get("environment"))
        if environment_name is None and isinstance(payload.get("data"), dict):
            environment_name = _optional_text(payload["data"].get("environment"))
        if environment_name not in self._verifiers:
            raise AppStoreVerificationError("Unsupported App Store environment")
        return self._verifiers[environment_name]

    def _transaction_from_payload(self, payload) -> VerifiedSubscriptionTransaction:
        original_transaction_id = str(payload.originalTransactionId or "").strip()
        transaction_id = str(payload.transactionId or "").strip()
        product_id = str(payload.productId or "").strip()
        expires_at = _milliseconds_to_seconds(payload.expiresDate)
        environment = _environment_name(payload.environment)
        if (
            not original_transaction_id
            or not transaction_id
            or product_id not in self._allowed_product_ids
            or expires_at is None
            or environment not in self._allowed_environments
        ):
            raise AppStoreVerificationError("Transaction is not an eligible subscription")
        return VerifiedSubscriptionTransaction(
            original_transaction_id=original_transaction_id,
            transaction_id=transaction_id,
            product_id=product_id,
            expires_at=expires_at,
            revocation_at=_milliseconds_to_seconds(payload.revocationDate),
            signed_at=_milliseconds_to_seconds(payload.signedDate) or int(time.time()),
            environment=environment,
        )


class CoachEntitlementStore:
    """Durable entitlement, token, and monthly reply allowance state."""

    def __init__(
        self,
        database_path: Path,
        access_token_secret: str,
        reply_limit: int,
        access_token_ttl_seconds: int,
        clock=time.time,
    ):
        if len(access_token_secret.encode("utf-8")) < 32:
            raise ValueError("COACH_ACCESS_TOKEN_SECRET must be at least 32 bytes")
        if reply_limit < 1 or access_token_ttl_seconds < 30:
            raise ValueError("Invalid Coach access token configuration")
        self._database_path = database_path
        self._token_secret = access_token_secret.encode("utf-8")
        self._reply_limit = reply_limit
        self._access_token_ttl_seconds = access_token_ttl_seconds
        self._clock = clock

    def initialize(self) -> None:
        self._database_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS subscription_entitlements (
                    original_transaction_id TEXT PRIMARY KEY,
                    product_id TEXT NOT NULL,
                    expires_at INTEGER NOT NULL,
                    grace_period_expires_at INTEGER,
                    revocation_at INTEGER,
                    signed_at INTEGER NOT NULL,
                    environment TEXT NOT NULL,
                    renewal_product_id TEXT,
                    renewal_auto_renew_status INTEGER,
                    renewal_in_billing_retry_period INTEGER,
                    renewal_expiration_intent INTEGER,
                    renewal_signed_at INTEGER,
                    updated_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS processed_app_store_notifications (
                    notification_uuid TEXT PRIMARY KEY,
                    notification_type TEXT NOT NULL,
                    received_at INTEGER NOT NULL
                );
                CREATE TABLE IF NOT EXISTS coach_access_tokens (
                    token_digest TEXT PRIMARY KEY,
                    original_transaction_id TEXT NOT NULL,
                    app_attest_key_id TEXT NOT NULL,
                    expires_at INTEGER NOT NULL,
                    created_at INTEGER NOT NULL
                );
                CREATE INDEX IF NOT EXISTS coach_access_tokens_expiry
                    ON coach_access_tokens(expires_at);
                CREATE TABLE IF NOT EXISTS coach_reply_usage (
                    original_transaction_id TEXT NOT NULL,
                    month TEXT NOT NULL,
                    replies INTEGER NOT NULL,
                    PRIMARY KEY (original_transaction_id, month)
                );
                """
            )
            self._add_missing_subscription_columns(connection)

    def record_transaction(
        self,
        transaction: VerifiedSubscriptionTransaction,
        renewal: Optional[VerifiedRenewalInfo] = None,
    ) -> None:
        now = int(self._clock())
        with self._connect() as connection:
            self._record_transaction_with_connection(connection, transaction, renewal, now)

    def record_notification(
        self,
        notification_uuid: str,
        notification_type: str,
        transaction: Optional[VerifiedSubscriptionTransaction],
        renewal: Optional[VerifiedRenewalInfo],
    ) -> bool:
        now = int(self._clock())
        with self._connect() as connection:
            cursor = connection.execute(
                """
                INSERT OR IGNORE INTO processed_app_store_notifications (
                    notification_uuid, notification_type, received_at
                ) VALUES (?, ?, ?)
                """,
                (notification_uuid, notification_type, now),
            )
            if cursor.rowcount == 0:
                return False
            if transaction is not None:
                self._record_transaction_with_connection(connection, transaction, renewal, now)
            return True

    def issue_access_token(
        self, original_transaction_id: str, app_attest_key_id: str
    ) -> tuple[str, int, int]:
        now = int(self._clock())
        self._require_active_entitlement(original_transaction_id, now)
        token = secrets.token_urlsafe(32)
        expires_at = now + self._access_token_ttl_seconds
        month = _month_bucket(now)
        with self._connect() as connection:
            connection.execute(
                "DELETE FROM coach_access_tokens WHERE expires_at <= ?", (now,)
            )
            connection.execute(
                """
                INSERT INTO coach_access_tokens (
                    token_digest, original_transaction_id, app_attest_key_id,
                    expires_at, created_at
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    self._token_digest(token),
                    original_transaction_id,
                    app_attest_key_id,
                    expires_at,
                    now,
                ),
            )
            usage = connection.execute(
                """
                SELECT replies FROM coach_reply_usage
                WHERE original_transaction_id = ? AND month = ?
                """,
                (original_transaction_id, month),
            ).fetchone()
        remaining = max(self._reply_limit - (usage[0] if usage else 0), 0)
        return token, expires_at, remaining

    def consume_reply_allowance(
        self, token: str, app_attest_key_id: str
    ) -> tuple[str, int]:
        now = int(self._clock())
        month = _month_bucket(now)
        with self._connect() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                """
                SELECT original_transaction_id, app_attest_key_id, expires_at
                FROM coach_access_tokens WHERE token_digest = ?
                """,
                (self._token_digest(token),),
            ).fetchone()
            if row is None or row[2] <= now:
                raise CoachAccessError("Coach access token expired")
            if not hmac.compare_digest(row[1], app_attest_key_id):
                raise CoachAccessError("Coach access token is not bound to this app")
            self._require_active_entitlement_with_connection(connection, row[0], now)
            usage = connection.execute(
                """
                SELECT replies FROM coach_reply_usage
                WHERE original_transaction_id = ? AND month = ?
                """,
                (row[0], month),
            ).fetchone()
            replies = usage[0] if usage else 0
            if replies >= self._reply_limit:
                raise CoachAccessError("Monthly Coach reply allowance reached")
            if usage:
                connection.execute(
                    """
                    UPDATE coach_reply_usage SET replies = replies + 1
                    WHERE original_transaction_id = ? AND month = ?
                    """,
                    (row[0], month),
                )
            else:
                connection.execute(
                    """
                    INSERT INTO coach_reply_usage (
                        original_transaction_id, month, replies
                    ) VALUES (?, ?, 1)
                    """,
                    (row[0], month),
                )
            return row[0], self._reply_limit - replies - 1

    def _record_transaction_with_connection(
        self, connection, transaction, renewal, now):
        grace_period_expires_at = (
            renewal.grace_period_expires_at if renewal is not None else None
        )
        renewal_product_id = renewal.product_id if renewal is not None else None
        renewal_auto_renew_status = (
            renewal.auto_renew_status if renewal is not None else None
        )
        renewal_in_billing_retry_period = (
            int(renewal.is_in_billing_retry_period)
            if renewal is not None and renewal.is_in_billing_retry_period is not None
            else None
        )
        renewal_expiration_intent = (
            renewal.expiration_intent if renewal is not None else None
        )
        renewal_signed_at = renewal.signed_at if renewal is not None else None
        connection.execute(
            """
            INSERT INTO subscription_entitlements (
                original_transaction_id, product_id, expires_at,
                grace_period_expires_at, revocation_at, signed_at,
                environment, renewal_product_id, renewal_auto_renew_status,
                renewal_in_billing_retry_period, renewal_expiration_intent,
                renewal_signed_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(original_transaction_id) DO UPDATE SET
                product_id = excluded.product_id,
                expires_at = CASE WHEN excluded.expires_at > subscription_entitlements.expires_at
                    THEN excluded.expires_at ELSE subscription_entitlements.expires_at END,
                grace_period_expires_at = CASE
                    WHEN excluded.grace_period_expires_at IS NULL
                        THEN subscription_entitlements.grace_period_expires_at
                    WHEN subscription_entitlements.grace_period_expires_at IS NULL
                        OR excluded.grace_period_expires_at > subscription_entitlements.grace_period_expires_at
                        THEN excluded.grace_period_expires_at
                    ELSE subscription_entitlements.grace_period_expires_at END,
                revocation_at = CASE
                    WHEN excluded.revocation_at IS NOT NULL THEN excluded.revocation_at
                    ELSE subscription_entitlements.revocation_at END,
                signed_at = MAX(excluded.signed_at, subscription_entitlements.signed_at),
                environment = excluded.environment,
                renewal_product_id = CASE WHEN excluded.renewal_signed_at IS NOT NULL
                    AND (subscription_entitlements.renewal_signed_at IS NULL
                    OR excluded.renewal_signed_at >= subscription_entitlements.renewal_signed_at)
                    THEN excluded.renewal_product_id
                    ELSE subscription_entitlements.renewal_product_id END,
                renewal_auto_renew_status = CASE WHEN excluded.renewal_signed_at IS NOT NULL
                    AND (subscription_entitlements.renewal_signed_at IS NULL
                    OR excluded.renewal_signed_at >= subscription_entitlements.renewal_signed_at)
                    THEN excluded.renewal_auto_renew_status
                    ELSE subscription_entitlements.renewal_auto_renew_status END,
                renewal_in_billing_retry_period = CASE WHEN excluded.renewal_signed_at IS NOT NULL
                    AND (subscription_entitlements.renewal_signed_at IS NULL
                    OR excluded.renewal_signed_at >= subscription_entitlements.renewal_signed_at)
                    THEN excluded.renewal_in_billing_retry_period
                    ELSE subscription_entitlements.renewal_in_billing_retry_period END,
                renewal_expiration_intent = CASE WHEN excluded.renewal_signed_at IS NOT NULL
                    AND (subscription_entitlements.renewal_signed_at IS NULL
                    OR excluded.renewal_signed_at >= subscription_entitlements.renewal_signed_at)
                    THEN excluded.renewal_expiration_intent
                    ELSE subscription_entitlements.renewal_expiration_intent END,
                renewal_signed_at = CASE WHEN excluded.renewal_signed_at IS NOT NULL
                    AND (subscription_entitlements.renewal_signed_at IS NULL
                    OR excluded.renewal_signed_at >= subscription_entitlements.renewal_signed_at)
                    THEN excluded.renewal_signed_at
                    ELSE subscription_entitlements.renewal_signed_at END,
                updated_at = excluded.updated_at
            """,
            (
                transaction.original_transaction_id,
                transaction.product_id,
                transaction.expires_at,
                grace_period_expires_at,
                transaction.revocation_at,
                transaction.signed_at,
                transaction.environment,
                renewal_product_id,
                renewal_auto_renew_status,
                renewal_in_billing_retry_period,
                renewal_expiration_intent,
                renewal_signed_at,
                now,
            ),
        )

    @staticmethod
    def _add_missing_subscription_columns(connection):
        for column_definition in (
            "renewal_product_id TEXT",
            "renewal_auto_renew_status INTEGER",
            "renewal_in_billing_retry_period INTEGER",
            "renewal_expiration_intent INTEGER",
            "renewal_signed_at INTEGER",
        ):
            try:
                connection.execute(
                    "ALTER TABLE subscription_entitlements ADD COLUMN "
                    + column_definition
                )
            except sqlite3.OperationalError as error:
                if "duplicate column name" not in str(error).lower():
                    raise

    def _require_active_entitlement(self, original_transaction_id, now):
        with self._connect() as connection:
            self._require_active_entitlement_with_connection(
                connection, original_transaction_id, now
            )

    @staticmethod
    def _require_active_entitlement_with_connection(
        connection, original_transaction_id, now
    ):
        row = connection.execute(
            """
            SELECT expires_at, grace_period_expires_at, revocation_at
            FROM subscription_entitlements WHERE original_transaction_id = ?
            """,
            (original_transaction_id,),
        ).fetchone()
        if row is None or row[2] is not None:
            raise CoachAccessError("Active subscription required")
        expires_at = max(row[0], row[1] or 0)
        if expires_at <= now:
            raise CoachAccessError("Subscription expired")

    def _token_digest(self, token: str) -> str:
        return hmac.new(
            self._token_secret, token.encode("utf-8"), hashlib.sha256
        ).hexdigest()

    @contextmanager
    def _connect(self):
        connection = sqlite3.connect(self._database_path, timeout=10)
        connection.execute("PRAGMA foreign_keys = ON")
        try:
            yield connection
            connection.commit()
        except Exception:
            connection.rollback()
            raise
        finally:
            connection.close()


def load_root_certificates(paths: Iterable[Path]) -> list[bytes]:
    certificates = []
    for path in paths:
        certificate_data = path.read_bytes()
        if b"-----BEGIN CERTIFICATE-----" in certificate_data:
            certificate = x509.load_pem_x509_certificate(certificate_data)
            certificate_data = certificate.public_bytes(serialization.Encoding.DER)
        else:
            x509.load_der_x509_certificate(certificate_data)
        certificates.append(certificate_data)
    return certificates


def _unverified_jws_payload(signed_jws: str) -> dict:
    try:
        _, payload, _ = signed_jws.split(".", 2)
        padding = "=" * (-len(payload) % 4)
        decoded = base64.urlsafe_b64decode(payload + padding)
        value = json.loads(decoded.decode("utf-8"))
    except (ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AppStoreVerificationError("Malformed signed data") from error
    if not isinstance(value, dict):
        raise AppStoreVerificationError("Malformed signed data")
    return value


def _environment_from_name(name: str) -> Environment:
    try:
        return Environment(name)
    except ValueError as error:
        raise ValueError("Unsupported App Store environment") from error


def _environment_name(value) -> Optional[str]:
    return value.value if isinstance(value, Environment) else _optional_text(value)


def _optional_text(value) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _milliseconds_to_seconds(value) -> Optional[int]:
    if value is None:
        return None
    try:
        return int(value) // 1000
    except (TypeError, ValueError) as error:
        raise AppStoreVerificationError("Invalid App Store timestamp") from error


def _optional_int(value) -> Optional[int]:
    if value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError) as error:
        raise AppStoreVerificationError("Invalid App Store value") from error


def _month_bucket(timestamp: int) -> str:
    return time.strftime("%Y-%m", time.gmtime(timestamp))
