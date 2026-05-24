# TeoPateo Coach Proxy

Small Python service that keeps the OpenRouter API key on the VPS and exposes the app-facing coach endpoint:

```text
POST /v1/coach/reply
GET /health
```

The app should call:

```text
https://82.38.4.88.sslip.io/v1/coach/reply
```

## Environment

Runtime configuration lives in `/etc/teopateo-coach.env` on the VPS:

```sh
HOST=127.0.0.1
PORT=8091
OPENROUTER_API_KEY=replace-with-real-key
OPENROUTER_MODEL=openai/gpt-5-mini
OPENROUTER_APP_TITLE=TeoPateo
OPENROUTER_REFERER=https://82.38.4.88.sslip.io
TEOPATEO_COACH_PROXY_TOKEN=replace-with-generated-token
```

The proxy token is not a strong mobile-app secret because it must be shipped to the app, but it prevents a fully open public proxy during development. Keep the OpenRouter API key only on the VPS.

## App Configuration

Set these in the Xcode scheme or generated Info.plist values:

```sh
TEOPATEO_COACH_PROXY_URL=https://82.38.4.88.sslip.io/v1/coach/reply
TEOPATEO_COACH_PROXY_TOKEN=<value from /etc/teopateo-coach.env>
```

If `TEOPATEO_COACH_PROXY_URL` is not set, the app falls back to direct OpenRouter configuration.
