import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import coach_proxy


class FakeHandler:
    def __init__(self, headers, client_address=("127.0.0.1", 12345)):
        self.headers = headers
        self.client_address = client_address
        self.path = "/v1/coach/reply"


class CoachProxyTests(unittest.TestCase):
    def test_normalized_messages_strips_invalid_roles_and_limits_size(self):
        long_text = "x" * (coach_proxy.MAX_MESSAGE_CHARS + 50)
        messages = [
            {"role": "system", "content": "ignored"},
            {"role": "user", "content": long_text},
            {"role": "assistant", "content": "  useful reply  "},
            {"role": "tool", "content": "ignored"},
            "ignored",
        ]

        normalized = coach_proxy.normalized_messages(messages)

        self.assertEqual([item["role"] for item in normalized], ["user", "assistant"])
        self.assertEqual(len(normalized[0]["content"]), coach_proxy.MAX_MESSAGE_CHARS)
        self.assertEqual(normalized[1]["content"], "useful reply")

    def test_normalized_messages_caps_history_length(self):
        messages = [
            {"role": "user", "content": f"message {index}"}
            for index in range(coach_proxy.MAX_MESSAGES + 5)
        ]

        normalized = coach_proxy.normalized_messages(messages)

        self.assertEqual(len(normalized), coach_proxy.MAX_MESSAGES)
        self.assertEqual(normalized[-1]["content"], f"message {coach_proxy.MAX_MESSAGES - 1}")

    def test_system_prompt_contains_safety_guardrails_and_limits_context(self):
        prompt = coach_proxy.system_prompt("c" * (coach_proxy.MAX_CONTEXT_CHARS + 50))

        self.assertIn("not medical care", prompt)
        self.assertIn("Do not diagnose", prompt)
        self.assertIn("medications", prompt)
        self.assertIn("988", prompt)
        self.assertIn("911", prompt)
        self.assertIn("1-800-QUIT-NOW", prompt)
        self.assertNotIn("c" * (coach_proxy.MAX_CONTEXT_CHARS + 1), prompt)

    def test_health_payload_does_not_expose_provider_configuration(self):
        payload = coach_proxy.health_payload()

        self.assertEqual(payload, {"ok": True})
        self.assertNotIn("openrouterKeyConfigured", payload)
        self.assertNotIn("authRequired", payload)
        self.assertNotIn("model", payload)

    def test_validate_configuration_requires_proxy_token(self):
        original_token = coach_proxy.PROXY_TOKEN
        original_subscriptions_mode = coach_proxy.COACH_SUBSCRIPTIONS_MODE
        coach_proxy.PROXY_TOKEN = ""
        coach_proxy.COACH_SUBSCRIPTIONS_MODE = "disabled"
        try:
            with patch.dict(os.environ, {"OPENROUTER_API_KEY": "sk-or-v1-test"}, clear=False):
                with self.assertRaises(SystemExit):
                    coach_proxy.validate_configuration()
        finally:
            coach_proxy.PROXY_TOKEN = original_token
            coach_proxy.COACH_SUBSCRIPTIONS_MODE = original_subscriptions_mode

    def test_required_app_attest_mode_does_not_accept_shared_bearer(self):
        original_mode = coach_proxy.APP_ATTEST_MODE
        original_token = coach_proxy.PROXY_TOKEN
        original_verifier = coach_proxy.APP_ATTEST_VERIFIER
        coach_proxy.APP_ATTEST_MODE = "required"
        coach_proxy.PROXY_TOKEN = "shared-token"
        coach_proxy.APP_ATTEST_VERIFIER = None
        handler = FakeHandler({"Authorization": "Bearer shared-token"})
        try:
            self.assertFalse(coach_proxy.coach_request_authorized(handler, b"{}"))
        finally:
            coach_proxy.APP_ATTEST_MODE = original_mode
            coach_proxy.PROXY_TOKEN = original_token
            coach_proxy.APP_ATTEST_VERIFIER = original_verifier

    def test_monitor_mode_keeps_bearer_only_for_migration(self):
        original_mode = coach_proxy.APP_ATTEST_MODE
        original_token = coach_proxy.PROXY_TOKEN
        coach_proxy.APP_ATTEST_MODE = "monitor"
        coach_proxy.PROXY_TOKEN = "shared-token"
        handler = FakeHandler({"Authorization": "Bearer shared-token"})
        try:
            self.assertTrue(coach_proxy.coach_request_authorized(handler, b"{}"))
        finally:
            coach_proxy.APP_ATTEST_MODE = original_mode
            coach_proxy.PROXY_TOKEN = original_token

    def test_client_ip_ignores_spoofed_forwarded_headers_without_trusted_proxy(self):
        original_cidrs = coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS
        coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS = "173.245.48.0/20"
        handler = FakeHandler(
            {
                "X-Forwarded-For": "198.51.100.10",
                "CF-Connecting-IP": "198.51.100.10",
                "X-TeoPateo-CF-Connecting-IP": "198.51.100.10",
                "X-TeoPateo-Remote-IP": "203.0.113.9",
            },
            client_address=("127.0.0.1", 12345),
        )
        try:
            self.assertEqual(coach_proxy.client_ip(handler), "203.0.113.9")
        finally:
            coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS = original_cidrs

    def test_client_ip_trusts_cloudflare_header_from_trusted_proxy(self):
        original_cidrs = coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS
        coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS = "173.245.48.0/20"
        handler = FakeHandler(
            {
                "X-TeoPateo-CF-Connecting-IP": "198.51.100.11",
                "X-TeoPateo-Remote-IP": "173.245.48.5",
            },
            client_address=("127.0.0.1", 12345),
        )
        try:
            self.assertEqual(coach_proxy.client_ip(handler), "198.51.100.11")
        finally:
            coach_proxy.TRUSTED_CLIENT_IP_PROXY_CIDRS = original_cidrs

    def test_rate_limiter_prunes_expired_ip_buckets(self):
        original_window = coach_proxy.RATE_LIMIT_WINDOW_SECONDS
        original_limit = coach_proxy.RATE_LIMIT_REQUESTS
        coach_proxy.REQUEST_TIMES.clear()
        coach_proxy.RATE_LIMIT_WINDOW_SECONDS = 10
        coach_proxy.RATE_LIMIT_REQUESTS = 2
        try:
            with patch.object(coach_proxy.time, "time", return_value=100.0):
                self.assertFalse(coach_proxy.is_rate_limited("203.0.113.1"))
                self.assertFalse(coach_proxy.is_rate_limited("203.0.113.2"))

            with patch.object(coach_proxy.time, "time", return_value=111.0):
                self.assertFalse(coach_proxy.is_rate_limited("203.0.113.3"))

            self.assertNotIn("203.0.113.1", coach_proxy.REQUEST_TIMES)
            self.assertNotIn("203.0.113.2", coach_proxy.REQUEST_TIMES)
            self.assertIn("203.0.113.3", coach_proxy.REQUEST_TIMES)
        finally:
            coach_proxy.REQUEST_TIMES.clear()
            coach_proxy.RATE_LIMIT_WINDOW_SECONDS = original_window
            coach_proxy.RATE_LIMIT_REQUESTS = original_limit

    def test_rate_limiter_check_and_append_share_one_limit_window(self):
        original_window = coach_proxy.RATE_LIMIT_WINDOW_SECONDS
        original_limit = coach_proxy.RATE_LIMIT_REQUESTS
        coach_proxy.REQUEST_TIMES.clear()
        coach_proxy.RATE_LIMIT_WINDOW_SECONDS = 60
        coach_proxy.RATE_LIMIT_REQUESTS = 1
        try:
            with patch.object(coach_proxy.time, "time", return_value=100.0):
                self.assertFalse(coach_proxy.is_rate_limited("203.0.113.4"))
                self.assertTrue(coach_proxy.is_rate_limited("203.0.113.4"))
            self.assertEqual(len(coach_proxy.REQUEST_TIMES["203.0.113.4"]), 1)
        finally:
            coach_proxy.REQUEST_TIMES.clear()
            coach_proxy.RATE_LIMIT_WINDOW_SECONDS = original_window
            coach_proxy.RATE_LIMIT_REQUESTS = original_limit


if __name__ == "__main__":
    unittest.main()
