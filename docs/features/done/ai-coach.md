# AI Coach

## Status

Implemented as a native SwiftUI MVP using OpenRouter chat completions.

## What It Does

- Sends the recent coach conversation to an injected coach client.
- Adds quit-plan context, active trigger rules, progress, risk insights, recent cravings, recent slips, replacement activities, and support contact context to each request.
- Uses a non-shaming relapse-prevention system prompt that focuses on the next 10 minutes during craving moments.
- Persists user and assistant messages through the existing `coach_messages` repository table.
- Shows loading and failure states in the Coach tab.

## OpenRouter Configuration

The live client prefers the VPS proxy when this value is present:

- `TEOPATEO_COACH_PROXY_URL` (for example, `https://82.38.4.88.sslip.io/v1/coach/reply`)
- `TEOPATEO_COACH_PROXY_TOKEN` (optional app-facing proxy token)

If no proxy URL is configured, the app can still use direct OpenRouter development settings:

- `OPENROUTER_API_KEY`
- `OPENROUTER_MODEL` (optional, defaults to `openai/gpt-5-mini`)
- `OPENROUTER_APP_TITLE` (optional, defaults to `TeoPateo`)
- `OPENROUTER_REFERER` (optional)
- `OPENROUTER_BASE_URL` (optional, defaults to `https://openrouter.ai/api/v1`)

These can come from the app process environment or generated Info.plist values. Do not commit provider keys to source.

The VPS proxy keeps the real OpenRouter key in `/etc/teopateo-coach.env` and runs the Python service in `server/coach-proxy/`.

## Product Boundaries

- The coach should keep replies practical, short, and specific to quitting smoking.
- Slip recovery remains framed as learning, not failure.
- Medication and health questions should direct the user to a doctor, pharmacist, quitline counselor, or emergency support when appropriate.
- A production subscription app should keep using a backend proxy or user-scoped credential flow instead of shipping a shared provider key in the iOS binary.
