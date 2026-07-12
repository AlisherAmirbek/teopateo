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
OPENROUTER_MODEL=deepseek/deepseek-v4-flash
OPENROUTER_APP_TITLE=TeoPateo
OPENROUTER_REFERER=https://82.38.4.88.sslip.io
TEOPATEO_COACH_PROXY_TOKEN=replace-with-generated-token
RATE_LIMIT_WINDOW_SECONDS=60
RATE_LIMIT_REQUESTS=20
UPSTREAM_TIMEOUT_SECONDS=45
APP_ATTEST_MODE=required
APP_ATTEST_APP_ID=A2RM3XYB3K.com.teopateo.TeoPateo
APP_ATTEST_ENVIRONMENT=production
APP_ATTEST_ALLOWED_CATEGORIES=2,4
APP_ATTEST_BUNDLE_VERSION=1.0
APP_ATTEST_DATABASE_PATH=/var/lib/teopateo-coach/app-attest.sqlite3
APP_ATTEST_ROOT_CA_PATH=/opt/teopateo-coach/Apple_App_Attestation_Root_CA.pem
```

`APP_ATTEST_MODE=required` rejects coach requests unless the iOS app supplies a valid assertion from an Apple-attested installation. The bearer token remains useful only with `disabled` or `monitor` mode during development and migration; it is not accepted as production authorization in required mode. Keep the OpenRouter API key only on the VPS. The env file should remain root-readable only:

```sh
chmod 600 /etc/teopateo-coach.env
```

## App Configuration

Set these in the Xcode scheme, simulator user defaults, or generated Info.plist values:

```sh
TEOPATEO_COACH_PROXY_URL=https://82.38.4.88.sslip.io/v1/coach/reply
```

Release builds contain the production proxy endpoint and use App Attest instead of an embedded bearer token. Direct OpenRouter access is compiled only for Debug development.

## App Attest flow

The proxy exposes two setup endpoints in addition to the coach endpoint:

```text
POST /v1/app-attest/challenge
POST /v1/app-attest/register
```

The iOS client generates an App Attest key, obtains a single-use challenge, and sends the Apple attestation object to the registration endpoint. The proxy validates the Apple certificate chain against the checked-in Apple App Attestation root, verifies the challenge nonce, App ID, environment, key identifier, and any validation-category and bundle-version extensions supplied by the OS, then stores the public key and receipt in SQLite.

Every coach request obtains a new assertion challenge. The assertion signs client data containing the challenge plus the exact HTTP method, path, and request-body hash. The proxy verifies the signature and advances the stored monotonic counter atomically, rejecting replayed or modified requests.

Install the Python dependencies before starting the service:

```sh
python3 -m pip install -r requirements.txt
```

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
