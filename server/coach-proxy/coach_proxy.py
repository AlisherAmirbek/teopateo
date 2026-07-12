#!/usr/bin/env python3
import base64
import binascii
import hmac
import json
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from app_attest import (
    AppAttestError,
    AppAttestStore,
    AppAttestVerifier,
    ChallengeStore,
)


HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8091"))
OPENROUTER_URL = os.getenv(
    "OPENROUTER_URL",
    "https://openrouter.ai/api/v1/chat/completions",
)
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "deepseek/deepseek-v4-flash")
APP_TITLE = os.getenv("OPENROUTER_APP_TITLE", "TeoPateo")
REFERER = os.getenv("OPENROUTER_REFERER", "")
PROXY_TOKEN = os.getenv("TEOPATEO_COACH_PROXY_TOKEN", "")
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "20"))
UPSTREAM_TIMEOUT_SECONDS = int(os.getenv("UPSTREAM_TIMEOUT_SECONDS", "45"))
APP_ATTEST_MODE = os.getenv("APP_ATTEST_MODE", "disabled").strip().lower()
APP_ATTEST_APP_ID = os.getenv(
    "APP_ATTEST_APP_ID",
    "A2RM3XYB3K.com.teopateo.TeoPateo",
).strip()
APP_ATTEST_ENVIRONMENT = os.getenv("APP_ATTEST_ENVIRONMENT", "production").strip().lower()
APP_ATTEST_ALLOWED_CATEGORIES = os.getenv("APP_ATTEST_ALLOWED_CATEGORIES", "2,4")
APP_ATTEST_BUNDLE_VERSION = os.getenv("APP_ATTEST_BUNDLE_VERSION", "1.0").strip()
APP_ATTEST_DATABASE_PATH = os.getenv(
    "APP_ATTEST_DATABASE_PATH",
    "/var/lib/teopateo-coach/app-attest.sqlite3",
)
APP_ATTEST_ROOT_CA_PATH = os.getenv(
    "APP_ATTEST_ROOT_CA_PATH",
    "/opt/teopateo-coach/Apple_App_Attestation_Root_CA.pem",
)
APP_ATTEST_CHALLENGE_TTL_SECONDS = int(
    os.getenv("APP_ATTEST_CHALLENGE_TTL_SECONDS", "300")
)
APP_ATTEST_MAX_OUTSTANDING_CHALLENGES = int(
    os.getenv("APP_ATTEST_MAX_OUTSTANDING_CHALLENGES", "10000")
)
MAX_CONTEXT_CHARS = 6000
MAX_MESSAGE_CHARS = 4000
MAX_MESSAGES = 12
MAX_REQUEST_BYTES = 100_000

SYSTEM_PROMPT = """You are TeoPateo's quit-smoking coach. Help the user get through high-risk smoking moments, refine their quit plan, reflect on check-ins, recover from slips, and understand patterns.

Keep the tone calm, specific, and non-shaming. Treat slips as data, not failure. Prioritize the next 10 minutes: name the trigger, choose one replacement action, and lower intensity.

Keep replies concise and practical. The coach is not medical care, emergency care, or a replacement for a clinician. Do not diagnose, guarantee outcomes, make strong medical claims, or tell users to start, stop, or change medications. For cessation medication questions, direct users to a doctor, pharmacist, or quitline counselor.

If the user describes immediate danger, self-harm, suicidal intent, severe withdrawal symptoms, chest pain, trouble breathing, or another emergency, tell them to contact local emergency services now. For US users, mention 988 for emotional crisis, 911 for immediate danger, and 1-800-QUIT-NOW for quitline support."""


def system_prompt(context_summary):
    return f"{SYSTEM_PROMPT}\n\nCurrent TeoPateo user context:\n{context_summary[:MAX_CONTEXT_CHARS]}"

REQUEST_TIMES = {}
REQUEST_TIMES_LOCK = threading.Lock()
APP_ATTEST_VERIFIER = None


class UpstreamServiceError(RuntimeError):
    pass


def health_payload():
    return {"ok": True}


def validate_configuration():
    errors = []
    if not os.getenv("OPENROUTER_API_KEY", "").strip():
        errors.append("OPENROUTER_API_KEY is required")
    if not OPENROUTER_MODEL.strip():
        errors.append("OPENROUTER_MODEL is required")
    if not OPENROUTER_URL.startswith("https://"):
        errors.append("OPENROUTER_URL must use https")
    if APP_ATTEST_MODE not in ("disabled", "monitor", "required"):
        errors.append("APP_ATTEST_MODE must be disabled, monitor, or required")
    if APP_ATTEST_MODE != "required" and not PROXY_TOKEN.strip():
        errors.append("TEOPATEO_COACH_PROXY_TOKEN is required")
    if RATE_LIMIT_WINDOW_SECONDS < 1:
        errors.append("RATE_LIMIT_WINDOW_SECONDS must be positive")
    if RATE_LIMIT_REQUESTS < 1:
        errors.append("RATE_LIMIT_REQUESTS must be positive")
    if UPSTREAM_TIMEOUT_SECONDS < 1:
        errors.append("UPSTREAM_TIMEOUT_SECONDS must be positive")
    if APP_ATTEST_MODE != "disabled":
        if not APP_ATTEST_APP_ID:
            errors.append("APP_ATTEST_APP_ID is required")
        if APP_ATTEST_ENVIRONMENT not in ("development", "production"):
            errors.append("APP_ATTEST_ENVIRONMENT must be development or production")
        if not APP_ATTEST_BUNDLE_VERSION:
            errors.append("APP_ATTEST_BUNDLE_VERSION is required")
        if APP_ATTEST_CHALLENGE_TTL_SECONDS < 30:
            errors.append("APP_ATTEST_CHALLENGE_TTL_SECONDS must be at least 30")
        if APP_ATTEST_MAX_OUTSTANDING_CHALLENGES < 1:
            errors.append("APP_ATTEST_MAX_OUTSTANDING_CHALLENGES must be positive")
        if not _allowed_app_attest_categories():
            errors.append("APP_ATTEST_ALLOWED_CATEGORIES must contain integers")

    if errors:
        for error in errors:
            print(f"configuration error: {error}", file=sys.stderr, flush=True)
        raise SystemExit(1)


def json_response(handler, status, body):
    payload = json.dumps(body).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(payload)))
    handler.end_headers()
    handler.wfile.write(payload)


def client_ip(handler):
    forwarded = handler.headers.get("X-Forwarded-For", "")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return handler.client_address[0]


def is_rate_limited(ip):
    now = time.time()
    cutoff = now - RATE_LIMIT_WINDOW_SECONDS

    with REQUEST_TIMES_LOCK:
        for tracked_ip, times in list(REQUEST_TIMES.items()):
            while times and times[0] <= cutoff:
                times.popleft()
            if not times:
                del REQUEST_TIMES[tracked_ip]

        times = REQUEST_TIMES.setdefault(ip, deque())
        if len(times) >= RATE_LIMIT_REQUESTS:
            return True

        times.append(now)
        return False


def authorized(handler):
    if not PROXY_TOKEN:
        return True
    supplied = handler.headers.get("Authorization", "")
    return hmac.compare_digest(supplied, f"Bearer {PROXY_TOKEN}")


def initialize_app_attest():
    global APP_ATTEST_VERIFIER
    if APP_ATTEST_MODE == "disabled":
        APP_ATTEST_VERIFIER = None
        return

    APP_ATTEST_VERIFIER = AppAttestVerifier(
        app_id=APP_ATTEST_APP_ID,
        environment=APP_ATTEST_ENVIRONMENT,
        allowed_categories=_allowed_app_attest_categories(),
        bundle_version=APP_ATTEST_BUNDLE_VERSION,
        root_certificate_path=Path(APP_ATTEST_ROOT_CA_PATH),
        challenge_store=ChallengeStore(
            APP_ATTEST_CHALLENGE_TTL_SECONDS,
            APP_ATTEST_MAX_OUTSTANDING_CHALLENGES,
            time.time,
        ),
        key_store=AppAttestStore(Path(APP_ATTEST_DATABASE_PATH), time.time),
    )
    APP_ATTEST_VERIFIER.initialize()


def _allowed_app_attest_categories():
    values = set()
    for item in APP_ATTEST_ALLOWED_CATEGORIES.split(","):
        stripped = item.strip()
        if not stripped or not stripped.isdigit():
            return set()
        values.add(int(stripped))
    return values


def app_attest_enabled():
    return APP_ATTEST_MODE in ("monitor", "required") and APP_ATTEST_VERIFIER is not None


def request_has_app_attest_headers(handler):
    return any(
        handler.headers.get(name)
        for name in (
            "X-TeoPateo-App-Attest-Key-Id",
            "X-TeoPateo-App-Attest-Challenge-Id",
            "X-TeoPateo-App-Attest-Assertion",
            "X-TeoPateo-App-Attest-Client-Data",
        )
    )


def app_attest_authorized(handler, request_body):
    if not app_attest_enabled():
        return False

    key_id = handler.headers.get("X-TeoPateo-App-Attest-Key-Id", "")
    challenge_id = handler.headers.get("X-TeoPateo-App-Attest-Challenge-Id", "")
    assertion = _decode_header_base64(
        handler,
        "X-TeoPateo-App-Attest-Assertion",
        MAX_REQUEST_BYTES,
    )
    client_data = _decode_header_base64(
        handler,
        "X-TeoPateo-App-Attest-Client-Data",
        4096,
    )
    if not key_id or len(key_id) > 1024 or not challenge_id or len(challenge_id) > 256:
        raise AppAttestError("Missing App Attest identity")

    APP_ATTEST_VERIFIER.verify_assertion(
        challenge_id,
        key_id,
        assertion,
        client_data,
        request_body,
        "POST",
        handler.path,
    )
    return True


def coach_request_authorized(handler, request_body):
    if request_has_app_attest_headers(handler):
        try:
            return app_attest_authorized(handler, request_body)
        except AppAttestError as error:
            print(f"app attest rejection: {error}", file=sys.stderr, flush=True)
            return False
    if APP_ATTEST_MODE == "required":
        return False
    return authorized(handler)


def _decode_header_base64(handler, name, maximum_bytes):
    value = handler.headers.get(name, "")
    if not value or len(value) > ((maximum_bytes * 4 // 3) + 8):
        raise AppAttestError(f"Invalid {name} header")
    try:
        decoded = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        raise AppAttestError(f"Invalid {name} header") from error
    if len(decoded) > maximum_bytes:
        raise AppAttestError(f"Invalid {name} header")
    return decoded


def normalized_messages(messages):
    normalized = []
    if not isinstance(messages, list):
        return normalized

    for item in messages[:MAX_MESSAGES]:
        if not isinstance(item, dict):
            continue
        role = item.get("role")
        content = str(item.get("content", "")).strip()
        if role not in ("user", "assistant") or not content:
            continue
        normalized.append({
            "role": role,
            "content": content[:MAX_MESSAGE_CHARS],
        })
    return normalized


def openrouter_reply(context_summary, messages):
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        raise UpstreamServiceError("OPENROUTER_API_KEY is not configured on the coach proxy.")

    body = {
        "model": OPENROUTER_MODEL,
        "temperature": 0.45,
        "max_tokens": 280,
        "messages": [
            {"role": "system", "content": system_prompt(context_summary)},
            *messages,
        ],
    }

    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        OPENROUTER_URL,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-OpenRouter-Title": APP_TITLE,
        },
    )
    if REFERER:
        request.add_header("HTTP-Referer", REFERER)

    try:
        with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT_SECONDS) as response:
            response_body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise UpstreamServiceError(f"OpenRouter returned {error.code}: {detail}") from error
    except (urllib.error.URLError, TimeoutError, socket.timeout) as error:
        raise UpstreamServiceError(f"OpenRouter request failed: {error}") from error

    decoded = json.loads(response_body.decode("utf-8"))
    reply = (
        decoded.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "")
        .strip()
    )
    if not reply:
        raise UpstreamServiceError("OpenRouter returned an empty coach reply.")
    return reply


def openrouter_stream_reply(handler, context_summary, messages):
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        raise UpstreamServiceError("OPENROUTER_API_KEY is not configured on the coach proxy.")

    body = {
        "model": OPENROUTER_MODEL,
        "temperature": 0.45,
        "max_tokens": 280,
        "stream": True,
        "messages": [
            {"role": "system", "content": system_prompt(context_summary)},
            *messages,
        ],
    }

    data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        OPENROUTER_URL,
        data=data,
        method="POST",
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "X-OpenRouter-Title": APP_TITLE,
        },
    )
    if REFERER:
        request.add_header("HTTP-Referer", REFERER)

    try:
        with urllib.request.urlopen(request, timeout=UPSTREAM_TIMEOUT_SECONDS) as response:
            handler.send_response(200)
            handler.send_header("Content-Type", "text/event-stream")
            handler.send_header("Cache-Control", "no-cache")
            handler.end_headers()

            received_content = False
            try:
                while True:
                    raw_line = response.readline()
                    if not raw_line:
                        break
                    line = raw_line.decode("utf-8", errors="replace").strip()
                    if not line.startswith("data:"):
                        continue

                    payload = line[len("data:"):].strip()
                    if payload == "[DONE]":
                        break

                    try:
                        decoded = json.loads(payload)
                    except json.JSONDecodeError:
                        continue
                    delta = (
                        decoded.get("choices", [{}])[0]
                        .get("delta", {})
                        .get("content", "")
                    )
                    if not delta:
                        continue

                    received_content = True
                    event = json.dumps({"delta": delta}).encode("utf-8")
                    handler.wfile.write(b"data: " + event + b"\n\n")
                    handler.wfile.flush()
            except (TimeoutError, socket.timeout) as error:
                print(f"upstream stream timeout: {error}", file=sys.stderr, flush=True)

            handler.wfile.write(b"data: [DONE]\n\n")
            handler.wfile.flush()
            handler.close_connection = True
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise UpstreamServiceError(f"OpenRouter returned {error.code}: {detail}") from error
    except (urllib.error.URLError, TimeoutError, socket.timeout) as error:
        raise UpstreamServiceError(f"OpenRouter request failed: {error}") from error


class CoachProxyHandler(BaseHTTPRequestHandler):
    server_version = "TeoPateoCoachProxy/1.0"

    def log_message(self, fmt, *args):
        print(
            "%s - - [%s] %s"
            % (client_ip(self), self.log_date_time_string(), fmt % args),
            flush=True,
        )

    def do_GET(self):
        if self.path != "/health":
            json_response(self, 404, {"error": "Not found"})
            return

        json_response(self, 200, health_payload())

    def do_POST(self):
        if self.path == "/v1/app-attest/challenge":
            self._handle_app_attest_challenge()
            return
        if self.path == "/v1/app-attest/register":
            self._handle_app_attest_registration()
            return
        if self.path != "/v1/coach/reply":
            json_response(self, 404, {"error": "Not found"})
            return

        ip = client_ip(self)
        if is_rate_limited(ip):
            json_response(self, 429, {"error": "Rate limit exceeded"})
            return

        try:
            request_body = self._read_request_body(MAX_REQUEST_BYTES)
            if not coach_request_authorized(self, request_body):
                json_response(self, 401, {"error": "Unauthorized"})
                return
            payload = json.loads(request_body.decode("utf-8"))
            context_summary = str(payload.get("contextSummary", "")).strip()
            messages = normalized_messages(payload.get("messages", []))
            if not messages:
                json_response(self, 400, {"error": "At least one message is required"})
                return

            if bool(payload.get("stream", False)):
                openrouter_stream_reply(self, context_summary, messages)
                return

            reply = openrouter_reply(context_summary, messages)
            json_response(self, 200, {"reply": reply})
        except (UnicodeDecodeError, json.JSONDecodeError, ValueError):
            json_response(self, 400, {"error": "Invalid JSON"})
        except UpstreamServiceError as error:
            print(f"upstream error: {error}", file=sys.stderr, flush=True)
            json_response(self, 502, {"error": "Coach service unavailable"})
        except Exception as error:
            print(f"proxy error: {error}", file=sys.stderr, flush=True)
            json_response(self, 500, {"error": "Coach service unavailable"})

    def _handle_app_attest_challenge(self):
        if not app_attest_enabled():
            json_response(self, 404, {"error": "Not found"})
            return
        if is_rate_limited(client_ip(self)):
            json_response(self, 429, {"error": "Rate limit exceeded"})
            return

        try:
            payload = json.loads(self._read_request_body(4096).decode("utf-8"))
            purpose = payload.get("purpose") if isinstance(payload, dict) else None
            challenge = APP_ATTEST_VERIFIER.issue_challenge(purpose)
            json_response(self, 200, {
                "challengeId": challenge.identifier,
                "challenge": base64.b64encode(challenge.value).decode("ascii"),
                "expiresAt": int(challenge.expires_at),
            })
        except (AppAttestError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
            print(f"app attest challenge rejection: {error}", file=sys.stderr, flush=True)
            json_response(self, 400, {"error": "Invalid App Attest challenge request"})

    def _handle_app_attest_registration(self):
        if not app_attest_enabled():
            json_response(self, 404, {"error": "Not found"})
            return
        if is_rate_limited(client_ip(self)):
            json_response(self, 429, {"error": "Rate limit exceeded"})
            return

        try:
            payload = json.loads(
                self._read_request_body(MAX_REQUEST_BYTES).decode("utf-8")
            )
            if not isinstance(payload, dict):
                raise AppAttestError("Invalid registration payload")
            challenge_id = str(payload.get("challengeId", ""))
            key_id = str(payload.get("keyId", ""))
            attestation_value = str(payload.get("attestationObject", ""))
            if len(challenge_id) > 256 or len(key_id) > 1024:
                raise AppAttestError("Invalid registration identity")
            try:
                attestation_object = base64.b64decode(attestation_value, validate=True)
            except (ValueError, binascii.Error) as error:
                raise AppAttestError("Invalid attestation encoding") from error
            APP_ATTEST_VERIFIER.register_key(
                challenge_id,
                key_id,
                attestation_object,
            )
            json_response(self, 200, {"registered": True})
        except (AppAttestError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
            print(f"app attest registration rejection: {error}", file=sys.stderr, flush=True)
            json_response(self, 401, {"error": "Invalid App Attest registration"})

    def _read_request_body(self, maximum_bytes):
        length_text = self.headers.get("Content-Length", "0")
        if not length_text.isdigit():
            raise ValueError("Invalid request size")
        length = int(length_text)
        if length <= 0 or length > maximum_bytes:
            raise ValueError("Invalid request size")
        return self.rfile.read(length)


def main():
    validate_configuration()
    initialize_app_attest()
    server = ThreadingHTTPServer((HOST, PORT), CoachProxyHandler)
    print(f"TeoPateo coach proxy listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
