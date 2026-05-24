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
RATE_LIMIT_WINDOW_SECONDS=60
RATE_LIMIT_REQUESTS=20
UPSTREAM_TIMEOUT_SECONDS=45
```

The proxy token is not a strong mobile-app secret because it must be shipped to the app, but it prevents a fully open public proxy during development. Keep the OpenRouter API key only on the VPS. The env file should remain root-readable only:

```sh
chmod 600 /etc/teopateo-coach.env
```

## App Configuration

Set these in the Xcode scheme, simulator user defaults, or generated Info.plist values:

```sh
TEOPATEO_COACH_PROXY_URL=https://82.38.4.88.sslip.io/v1/coach/reply
TEOPATEO_COACH_PROXY_TOKEN=<value from /etc/teopateo-coach.env>
```

In release builds, `TEOPATEO_COACH_PROXY_URL` must be set. Direct OpenRouter access is compiled only for Debug development.

## Deployment Checks

```sh
systemctl status teopateo-coach
systemctl status caddy
curl -fsS https://82.38.4.88.sslip.io/health
```

The public health response is intentionally minimal:

```json
{"ok": true}
```

Provider errors and key/config details stay in `journalctl -u teopateo-coach`; they are not returned to the app.
