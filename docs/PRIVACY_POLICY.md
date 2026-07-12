# TeoPateo Privacy Policy

Effective date: July 12, 2026

TeoPateo is a quit-smoking companion. The app handles sensitive health-related information, so the default product posture is local-first storage and explicit consent before AI coach data leaves the device.

## Data Stored On Your Device

TeoPateo stores the following data locally on your device:

- Quit plan, quit date, taper/cold-turkey settings, and daily focus.
- Onboarding profile, including nickname, age, quit readiness, and smoking background.
- Check-ins, cravings, slips, triggers, reasons for quitting, replacement activities, and risky situations.
- Coach chat history and notification settings.

TeoPateo does not sync or back up this quit-history data to iCloud. This local data is not collected by TeoPateo unless you choose to use an off-device feature such as the AI coach. Release builds also send limited crash and error diagnostics as described below.

## AI Coach Data Sharing

The AI coach sends data off-device only after you explicitly allow coach data sharing.

When you send a coach message, TeoPateo sends your message plus a limited quit-plan context to the TeoPateo coach proxy. That context can include smoking history, check-ins, cravings, slips, triggers, reasons, replacement activities, risky situations, and recent coach messages.

The coach proxy forwards the request to an AI provider, currently OpenRouter, to generate a reply. The proxy enforces `MAX_CONTEXT_CHARS = 6000`, so quit-plan context is trimmed before forwarding. The proxy is designed without a long-term TeoPateo user account.

Production provider configuration should prefer no retention and no training on coach data.

## Crash and Error Diagnostics

Release builds use Sentry for crash reporting and handled-error diagnostics. Reports can include device and operating-system details, stack traces, and a coarse error category. TeoPateo disables Sentry's default personal information collection and does not attach quit-plan content, coach messages, or other user-entered health content to diagnostic events.

## Data Use

TeoPateo uses your data to:

- Build and update your quit plan.
- Show progress, insights, reminders, and craving support.
- Generate AI coach replies when coach sharing is enabled.

TeoPateo does not sell your data and does not use health-related coach data for advertising or cross-app tracking.

## Retention

Local app data remains on your device until you delete it or uninstall the app. Coach requests are used to return a coach reply. The coach proxy should not maintain a long-term user account for these requests. Diagnostic events are retained according to the configured Sentry project retention settings.

## Your Choices

You can decline AI coach sharing and continue using the rest of TeoPateo.

You can revoke AI coach sharing from Privacy & Data in the app. Revoking consent stops future coach sends unless you allow sharing again.

You can delete local TeoPateo data from Privacy & Data in the app. This removes your quit plan, onboarding profile, check-ins, cravings, slips, coach chats, reasons, activities, risky situations, notification settings, and coach sharing consent from this device.

You can request an export of data TeoPateo controls by emailing support@teopateo.app.

## Contact

For privacy or support requests, email support@teopateo.app.

## Under 18

If your profile age is under 18, TeoPateo asks you to use extra care with the AI coach and avoid sharing full names, contact details, or information you would not want a trusted adult to help you review.

## App Privacy Manifest Summary

The app target includes `PrivacyInfo.xcprivacy`.

The app declares:

- Health data and other user content collected only for app functionality when coach sharing sends data off-device.
- Crash data and diagnostics collected for app functionality without tracking.
- No tracking.
- `UserDefaults` access for app-only configuration using required-reason code `CA92.1`.

The bundled GRDB framework has its own privacy manifest.
