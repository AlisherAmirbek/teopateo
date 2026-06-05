# Privacy Policy and Data Disclosure

## Goal

Meet Apple's privacy requirements and be honest with users about what TeoPateo stores and what leaves the device, given that this is sensitive health data.

## Why This Is a Blocker

- The App Store requires a privacy policy URL and accurate App Privacy ("nutrition label") answers.
- Apple requires the app to ship its own privacy manifest (`PrivacyInfo.xcprivacy`). Today only the bundled GRDB framework has one; the app target has none.
- The AI coach sends user context — smoking history, check-ins, slips, and cravings — to a third-party LLM provider (OpenRouter). This data flow must be disclosed.

## Privacy Policy

- Host a policy and link it from App Store Connect and an in-app settings link.
- Describe what is stored locally, what is sent to the coach proxy and onward to the LLM, retention, and that the proxy holds no long-term user account.
- Cover the user's right to delete and export their data.

## App Privacy Manifest

- Add the app target's `PrivacyInfo.xcprivacy`.
- Declare required-reason API usage (e.g. `UserDefaults`, file-timestamp APIs) with the correct reason codes.
- Declare collected data types. Local-only data is not "collected" in Apple's sense, but coach data sent off-device is — classify Health & Fitness and any diagnostics accordingly.

## Coach Data Disclosure

- The policy and App Privacy answers must state that health-related context is transmitted to an AI provider to generate coach replies.
- Send no more context than the coach needs; document the `MAX_CONTEXT_CHARS` boundary the proxy already enforces.

## User Consent

Linking the policy is not enough for the coach: it sends health-related context to a third-party AI provider, which requires affirmative consent (Apple 5.1.1 / 5.1.2; GDPR Art. 9 treats this as special-category health data for EU users).

- Do **not** gate the whole app behind a privacy-policy "Accept" wall.
- Show a one-time consent sheet **before the coach's first off-device send**:
  - Plain-language description of what is shared and that it goes to an AI provider.
  - An explicit, un-prechecked "Allow" action.
  - A decline path that keeps the rest of the app usable (the coach is already a gated feature — see `subscription-packaging`).
  - A revoke toggle in Settings.
- Prefer a provider configuration with no retention or training on the data.
- Treat under-18 users with extra care; age is captured in onboarding.

Use an in-app modal/sheet, not a push notification — push is the wrong mechanism for consent.

## Acceptance Criteria

- Privacy policy hosted and linked from the listing and in-app.
- `PrivacyInfo.xcprivacy` present in the app target and consistent with the App Privacy answers.
- Coach/LLM data flow disclosed in plain language.
- The coach transmits no user data until explicit, revocable consent is recorded.
- Declining coach consent leaves the rest of the app fully usable.
- A user-facing data deletion path exists (ties to `data-durability-and-sync`).

## Related

- A Terms of Service / EULA should ship alongside the policy.
- See `coach-proxy-production-readiness` for how coach data is transmitted and protected.
