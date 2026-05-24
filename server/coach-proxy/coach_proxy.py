#!/usr/bin/env python3
import json
import os
import time
import urllib.error
import urllib.request
from collections import defaultdict, deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8091"))
OPENROUTER_URL = os.getenv(
    "OPENROUTER_URL",
    "https://openrouter.ai/api/v1/chat/completions",
)
OPENROUTER_MODEL = os.getenv("OPENROUTER_MODEL", "openai/gpt-5-mini")
APP_TITLE = os.getenv("OPENROUTER_APP_TITLE", "TeoPateo")
REFERER = os.getenv("OPENROUTER_REFERER", "")
PROXY_TOKEN = os.getenv("TEOPATEO_COACH_PROXY_TOKEN", "")
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_REQUESTS = int(os.getenv("RATE_LIMIT_REQUESTS", "20"))

SYSTEM_PROMPT = """You are TeoPateo's quit-smoking coach. Help the user get through high-risk smoking moments, refine their quit plan, reflect on check-ins, recover from slips, and understand patterns.

Keep the tone calm, specific, and non-shaming. Treat slips as data, not failure. Prioritize the next 10 minutes: name the trigger, choose one replacement action, lower intensity, and use support if needed.

Keep replies concise and practical. Do not diagnose, guarantee outcomes, or make strong medical claims. For medication, withdrawal symptoms, mental health concerns, or urgent safety concerns, direct the user to a doctor, pharmacist, quitline counselor, local emergency service, or trusted support person as appropriate."""


def system_prompt(context_summary):
    return f"{SYSTEM_PROMPT}\n\nCurrent TeoPateo user context:\n{context_summary[:6000]}"

REQUEST_TIMES = defaultdict(deque)


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
    times = REQUEST_TIMES[ip]
    while times and now - times[0] > RATE_LIMIT_WINDOW_SECONDS:
        times.popleft()
    if len(times) >= RATE_LIMIT_REQUESTS:
        return True
    times.append(now)
    return False


def authorized(handler):
    if not PROXY_TOKEN:
        return True
    return handler.headers.get("Authorization") == f"Bearer {PROXY_TOKEN}"


def normalized_messages(messages):
    normalized = []
    for item in messages[:12]:
        role = item.get("role")
        content = str(item.get("content", "")).strip()
        if role not in ("user", "assistant") or not content:
            continue
        normalized.append({
            "role": role,
            "content": content[:4000],
        })
    return normalized


def openrouter_reply(context_summary, messages):
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENROUTER_API_KEY is not configured on the coach proxy.")

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
        with urllib.request.urlopen(request, timeout=45) as response:
            response_body = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenRouter returned {error.code}: {detail}") from error

    decoded = json.loads(response_body.decode("utf-8"))
    reply = (
        decoded.get("choices", [{}])[0]
        .get("message", {})
        .get("content", "")
        .strip()
    )
    if not reply:
        raise RuntimeError("OpenRouter returned an empty coach reply.")
    return reply


def openrouter_stream_reply(handler, context_summary, messages):
    api_key = os.getenv("OPENROUTER_API_KEY", "").strip()
    if not api_key:
        raise RuntimeError("OPENROUTER_API_KEY is not configured on the coach proxy.")

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
        with urllib.request.urlopen(request, timeout=45) as response:
            handler.send_response(200)
            handler.send_header("Content-Type", "text/event-stream")
            handler.send_header("Cache-Control", "no-cache")
            handler.send_header("Connection", "keep-alive")
            handler.end_headers()

            received_content = False
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

            handler.wfile.write(b"data: [DONE]\n\n")
            handler.wfile.flush()
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenRouter returned {error.code}: {detail}") from error


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

        json_response(self, 200, {
            "ok": True,
            "model": OPENROUTER_MODEL,
            "openrouterKeyConfigured": bool(os.getenv("OPENROUTER_API_KEY", "").strip()),
            "authRequired": bool(PROXY_TOKEN),
        })

    def do_POST(self):
        if self.path != "/v1/coach/reply":
            json_response(self, 404, {"error": "Not found"})
            return

        if not authorized(self):
            json_response(self, 401, {"error": "Unauthorized"})
            return

        ip = client_ip(self)
        if is_rate_limited(ip):
            json_response(self, 429, {"error": "Rate limit exceeded"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            if length <= 0 or length > 80_000:
                json_response(self, 400, {"error": "Invalid request size"})
                return

            payload = json.loads(self.rfile.read(length).decode("utf-8"))
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
        except json.JSONDecodeError:
            json_response(self, 400, {"error": "Invalid JSON"})
        except RuntimeError as error:
            json_response(self, 502, {"error": str(error)})
        except Exception:
            json_response(self, 500, {"error": "Coach proxy failed unexpectedly"})


def main():
    server = ThreadingHTTPServer((HOST, PORT), CoachProxyHandler)
    print(f"TeoPateo coach proxy listening on {HOST}:{PORT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
