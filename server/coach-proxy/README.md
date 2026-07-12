# TeoPateo Coach Proxy

Small Python service that keeps the OpenRouter API key on the VPS and exposes the app-facing coach endpoint:

```text
POST /v1/coach/access
POST /v1/coach/reply
POST /v1/app-store/notifications
GET /health
```

The app should call:

```text
https://api.teopateo.app/v1/coach/reply
```

## Environment

Runtime configuration lives in `/etc/teopateo-coach.env` on the VPS:

```sh
HOST=127.0.0.1
PORT=8091
OPENROUTER_API_KEY=replace-with-real-key
OPENROUTER_MODEL=deepseek/deepseek-v4-flash
OPENROUTER_APP_TITLE=TeoPateo
OPENROUTER_REFERER=https://api.teopateo.app
TEOPATEO_COACH_PROXY_TOKEN=replace-with-generated-token
RATE_LIMIT_WINDOW_SECONDS=60
RATE_LIMIT_REQUESTS=20
TRUSTED_CLIENT_IP_PROXY_CIDRS=replace-with-comma-separated-cloudflare-ip-ranges
UPSTREAM_TIMEOUT_SECONDS=45
APP_ATTEST_MODE=required
APP_ATTEST_APP_ID=A2RM3XYB3K.com.teopateo.TeoPateo
APP_ATTEST_ENVIRONMENT=production
APP_ATTEST_ALLOWED_CATEGORIES=2,4
APP_ATTEST_BUNDLE_VERSION=1.0
APP_ATTEST_DATABASE_PATH=/var/lib/teopateo-coach/app-attest.sqlite3
APP_ATTEST_ROOT_CA_PATH=/opt/teopateo-coach/Apple_App_Attestation_Root_CA.pem
COACH_SUBSCRIPTIONS_MODE=required
COACH_ACCESS_TOKEN_SECRET=replace-with-a-random-32-byte-or-longer-secret
COACH_ACCESS_TOKEN_TTL_SECONDS=300
COACH_MONTHLY_REPLY_LIMIT=300
APP_STORE_BUNDLE_ID=com.teopateo.TeoPateo
APP_STORE_APPLE_ID=replace-with-the-numeric-App-Store-app-ID
APP_STORE_PRODUCT_IDS=com.teopateo.TeoPateo.premium.monthly,com.teopateo.TeoPateo.premium.yearly
APP_STORE_ALLOWED_ENVIRONMENTS=Sandbox,Production
APP_STORE_ROOT_CERTIFICATE_PATHS=/opt/teopateo-coach/AppleRootCA-G3.cer
APP_STORE_ENABLE_ONLINE_CHECKS=true
APP_STORE_ENTITLEMENT_DATABASE_PATH=/var/lib/teopateo-coach/subscriptions.sqlite3
```

`APP_ATTEST_MODE=required` rejects coach requests unless the iOS app supplies a valid assertion from an Apple-attested installation. The bearer token remains useful only with `disabled` or `monitor` mode during development and migration; it is not accepted as production authorization in required mode. Keep the OpenRouter API key only on the VPS. The env file should remain root-readable only:

`TRUSTED_CLIENT_IP_PROXY_CIDRS` should be populated from Cloudflare's current IPv4 and IPv6 ranges so the proxy only trusts `CF-Connecting-IP` when the request actually arrived from Cloudflare.

```sh
chmod 600 /etc/teopateo-coach.env
```

`COACH_SUBSCRIPTIONS_MODE=required` is the release default. It requires a valid App Attest assertion and a short-lived access token for every Coach reply. Do not change it to `disabled` outside a local development environment. `COACH_ACCESS_TOKEN_SECRET` is server-only; generate it with `openssl rand -base64 48` and do not put it in the app or repository.

Install Apple’s App Store Root CA G3 certificate at the configured path. The proxy verifies the certificate chain in every StoreKit transaction and App Store Server Notification JWS; it does not trust a product ID or expiration date supplied by the app. `APP_STORE_APPLE_ID` is the numeric ID from App Store Connect and is required whenever Production notifications are accepted.

## App Configuration

Set these in the Xcode scheme, simulator user defaults, or generated Info.plist values:

```sh
TEOPATEO_COACH_PROXY_URL=https://api.teopateo.app/v1/coach/reply
```

Release builds contain the production proxy endpoint and use App Attest instead of an embedded bearer token. Direct OpenRouter access is compiled only for Debug development.

## Subscription-enforced Coach flow

1. The app reads the current verified StoreKit transaction and sends its Apple-signed JWS to `POST /v1/coach/access`.
2. The proxy verifies the JWS against Apple’s certificate chain, checks the TeoPateo bundle ID and allowed subscription products, and records only the subscription transaction identity and access dates.
3. The proxy issues a five-minute access token bound to that installation’s App Attest key. The raw token is stored only in app memory; the server stores an HMAC digest.
4. Every `POST /v1/coach/reply` carries that access token plus a fresh App Attest assertion. The proxy re-checks subscription status and atomically consumes one of the 300 replies available to that subscription identity for the current UTC month.

The allowance is consumed when the proxy accepts a Coach request, before opening the upstream stream. This prevents a modified client from obtaining unlimited model calls by disconnecting mid-response.

Cancelling a subscription keeps access until the current paid period ends. Billing-retry and grace-period notifications preserve access through their verified expiry. Refunds and revocations immediately block existing tokens.

### App Store Server Notifications

In App Store Connect, configure the production and sandbox App Store Server Notifications V2 URL as:

```text
https://api.teopateo.app/v1/app-store/notifications
```

The endpoint accepts only a verified `signedPayload`, deduplicates `notificationUUID`, and processes the signed transaction and renewal information inside it. This updates expiry, renewal, billing-retry/grace-period, cancellation-at-expiry, and refund/revocation state even if the customer does not reopen the app.

Apple can retry notifications, so Caddy must forward this endpoint unchanged and the service’s SQLite state directory must be persistent and backed up. The notification endpoint has no shared bearer token; its JWS signature is the authentication mechanism.

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
curl -fsS https://api.teopateo.app/health
```

The public health response is intentionally minimal:

```json
{"ok": true}
```

Provider errors and key/config details stay in `journalctl -u teopateo-coach`; they are not returned to the app.
