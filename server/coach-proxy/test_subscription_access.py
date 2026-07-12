import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app_store import (
    CoachAccessError,
    CoachEntitlementStore,
    VerifiedRenewalInfo,
    VerifiedSubscriptionTransaction,
)


class CoachEntitlementStoreTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.now = [1_735_689_600]  # 2025-01-01T00:00:00Z
        self.store = CoachEntitlementStore(
            Path(self.temporary_directory.name) / "subscriptions.sqlite3",
            access_token_secret="s" * 32,
            reply_limit=3,
            access_token_ttl_seconds=300,
            clock=lambda: self.now[0],
        )
        self.store.initialize()
        self.active_transaction = VerifiedSubscriptionTransaction(
            original_transaction_id="original-transaction",
            transaction_id="transaction-1",
            product_id="com.teopateo.TeoPateo.premium.yearly",
            expires_at=self.now[0] + 3_600,
            revocation_at=None,
            signed_at=self.now[0],
            environment="Sandbox",
        )
        self.store.record_transaction(self.active_transaction)

    def tearDown(self):
        self.temporary_directory.cleanup()

    def test_access_token_is_bound_to_the_app_attest_identity_and_reply_limit(self):
        token, expires_at, remaining = self.store.issue_access_token(
            "original-transaction", "attest-key-a"
        )

        self.assertEqual(expires_at, self.now[0] + 300)
        self.assertEqual(remaining, 3)
        self.assertEqual(
            self.store.consume_reply_allowance(token, "attest-key-a"),
            ("original-transaction", 2),
        )
        with self.assertRaises(CoachAccessError):
            self.store.consume_reply_allowance(token, "attest-key-b")

        self.assertEqual(
            self.store.consume_reply_allowance(token, "attest-key-a"),
            ("original-transaction", 1),
        )
        self.assertEqual(
            self.store.consume_reply_allowance(token, "attest-key-a"),
            ("original-transaction", 0),
        )
        with self.assertRaises(CoachAccessError):
            self.store.consume_reply_allowance(token, "attest-key-a")

    def test_revocation_blocks_existing_access_tokens(self):
        token, _, _ = self.store.issue_access_token(
            "original-transaction", "attest-key-a"
        )
        self.store.record_transaction(
            VerifiedSubscriptionTransaction(
                original_transaction_id="original-transaction",
                transaction_id="transaction-2",
                product_id="com.teopateo.TeoPateo.premium.yearly",
                expires_at=self.now[0] + 3_600,
                revocation_at=self.now[0],
                signed_at=self.now[0] + 1,
                environment="Sandbox",
            )
        )

        with self.assertRaises(CoachAccessError):
            self.store.consume_reply_allowance(token, "attest-key-a")

    def test_notification_is_idempotent_and_grace_period_keeps_access_active(self):
        expired_transaction = VerifiedSubscriptionTransaction(
            original_transaction_id="grace-transaction",
            transaction_id="transaction-3",
            product_id="com.teopateo.TeoPateo.premium.monthly",
            expires_at=self.now[0] - 1,
            revocation_at=None,
            signed_at=self.now[0],
            environment="Sandbox",
        )
        renewal = VerifiedRenewalInfo(
            original_transaction_id="grace-transaction",
            product_id="com.teopateo.TeoPateo.premium.monthly",
            grace_period_expires_at=self.now[0] + 600,
            auto_renew_status=0,
            is_in_billing_retry_period=True,
            expiration_intent=2,
            signed_at=self.now[0],
        )

        self.assertTrue(
            self.store.record_notification(
                "notification-1", "DID_FAIL_TO_RENEW", expired_transaction, renewal
            )
        )
        self.assertFalse(
            self.store.record_notification(
                "notification-1", "DID_FAIL_TO_RENEW", expired_transaction, renewal
            )
        )
        connection = sqlite3.connect(
            Path(self.temporary_directory.name) / "subscriptions.sqlite3"
        )
        try:
            renewal_state = connection.execute(
                """
                SELECT renewal_auto_renew_status, renewal_in_billing_retry_period,
                    renewal_expiration_intent
                FROM subscription_entitlements
                WHERE original_transaction_id = ?
                """,
                ("grace-transaction",),
            ).fetchone()
        finally:
            connection.close()
        self.assertEqual(renewal_state, (0, 1, 2))
        token, _, _ = self.store.issue_access_token(
            "grace-transaction", "attest-key-a"
        )
        self.assertEqual(
            self.store.consume_reply_allowance(token, "attest-key-a")[0],
            "grace-transaction",
        )


if __name__ == "__main__":
    unittest.main()
