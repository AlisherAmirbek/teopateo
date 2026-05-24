# AI Coach

## Status

Implemented as a native SwiftUI MVP using the TeoPateo VPS coach proxy backed by OpenRouter chat completions.

## What It Does

- Sends the recent coach conversation to an injected coach client.
- Adds quit-plan context, active trigger rules, progress, risk insights, recent cravings, recent slips, and replacement activities to each request.
- Sends only app context and chat messages; the VPS proxy owns the production system prompt and provider call.
- Persists user and assistant messages through the existing `coach_messages` repository table.
- Shows loading and user-friendly failure states in the Coach tab.

## OpenRouter Configuration

Release builds use the VPS proxy:

- `TEOPATEO_COACH_PROXY_URL` (for example, `https://82.38.4.88.sslip.io/v1/coach/reply`)
- `TEOPATEO_COACH_PROXY_TOKEN` (app-facing development gate, not a strong secret)

Debug builds can fall back to direct OpenRouter development settings if no proxy URL is configured:

- `OPENROUTER_API_KEY`
- `OPENROUTER_MODEL` (optional, defaults to `openai/gpt-5-mini`)
- `OPENROUTER_APP_TITLE` (optional, defaults to `TeoPateo`)
- `OPENROUTER_REFERER` (optional)
- `OPENROUTER_BASE_URL` (optional, defaults to `https://openrouter.ai/api/v1`)

These can come from the app process environment or generated Info.plist values. Do not commit provider keys to source.

The VPS proxy keeps the real OpenRouter key in `/etc/teopateo-coach.env` and runs the Python service in `server/coach-proxy/`. Public `/health` intentionally exposes only `{"ok": true}`.

## Product Boundaries

- The coach should keep replies practical, short, and specific to quitting smoking.
- Slip recovery remains framed as learning, not failure.
- Medication and health questions should direct the user to a doctor, pharmacist, quitline counselor, or emergency support when appropriate.
- The production prompt tells the coach it is not medical or emergency care, must not diagnose, must not tell users to change medication, and should point US users to 988 for emotional crisis, 911 for immediate danger, and 1-800-QUIT-NOW for quitline support.
- A production subscription app should keep using a backend proxy or user-scoped credential flow instead of shipping a shared provider key in the iOS binary.
