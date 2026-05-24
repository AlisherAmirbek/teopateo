import os
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parent))

import coach_proxy


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
        coach_proxy.PROXY_TOKEN = ""
        try:
            with patch.dict(os.environ, {"OPENROUTER_API_KEY": "sk-or-v1-test"}, clear=False):
                with self.assertRaises(SystemExit):
                    coach_proxy.validate_configuration()
        finally:
            coach_proxy.PROXY_TOKEN = original_token


if __name__ == "__main__":
    unittest.main()
