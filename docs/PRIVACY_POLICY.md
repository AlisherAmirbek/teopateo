# TeoPateo Privacy Policy

Effective date: June 10, 2026

TeoPateo is a quit-smoking companion. The app handles sensitive health-related information, so the default product posture is local-first storage and explicit consent before AI coach data leaves the device.

## Data Stored On Your Device

TeoPateo stores the following data locally on your device:

- Quit plan, quit date, taper/cold-turkey settings, and daily focus.
- Onboarding profile, including nickname, age, quit readiness, and smoking background.
- Check-ins, cravings, slips, triggers, reasons for quitting, replacement activities, and risky situations.
- Coach chat history and notification settings.

This local-only data is not collected by TeoPateo unless you choose to use an off-device feature such as the AI coach or iCloud backup.

## iCloud Backup

If you turn on iCloud backup, TeoPateo copies the quit data listed above to your own private iCloud database so it survives losing or replacing your phone and follows you to a new device signed in to the same Apple ID.

- The backup is stored in your private iCloud database under your Apple ID. Only you can access it. TeoPateo's developers cannot read it, and it is not sent to TeoPateo's servers.
- The transfer goes directly between your device and Apple iCloud over an encrypted connection.
- iCloud backup is a per-device setting. You can turn it on or off at any time from Privacy & Data in the app.
- If you delete your local data while iCloud backup is on, TeoPateo also deletes the iCloud backup so the deleted data cannot be restored later.

## AI Coach Data Sharing

The AI coach sends data off-device only after you explicitly allow coach data sharing.

When you send a coach message, TeoPateo sends your message plus a limited quit-plan context to the TeoPateo coach proxy. That context can include smoking history, check-ins, cravings, slips, triggers, reasons, replacement activities, risky situations, and recent coach messages.

The coach proxy forwards the request to an AI provider, currently OpenRouter, to generate a reply. The proxy enforces `MAX_CONTEXT_CHARS = 6000`, so quit-plan context is trimmed before forwarding. The proxy is designed without a long-term TeoPateo user account.

Production provider configuration should prefer no retention and no training on coach data.

## Data Use

TeoPateo uses your data to:

- Build and update your quit plan.
- Show progress, insights, reminders, and craving support.
- Generate AI coach replies when coach sharing is enabled.

TeoPateo does not sell your data and does not use health-related coach data for advertising or cross-app tracking.

## Retention

Local app data remains on your device until you delete it or uninstall the app. Coach requests are used to return a coach reply. The coach proxy should not maintain a long-term user account for these requests.

## Your Choices

You can decline AI coach sharing and continue using the rest of TeoPateo.

You can revoke AI coach sharing from Privacy & Data in the app. Revoking consent stops future coach sends unless you allow sharing again.

You can turn iCloud backup on or off from Privacy & Data in the app. When it is on, your quit data is copied to your private iCloud; when it is off, your data stays only on this device.

You can delete local TeoPateo data from Privacy & Data in the app. This removes your quit plan, onboarding profile, check-ins, cravings, slips, coach chats, reasons, activities, risky situations, notification settings, and coach sharing consent from this device. If iCloud backup is on, your iCloud backup is deleted at the same time.

You can request an export of data TeoPateo controls through the contact path on the hosted privacy-policy page.

## Under 18

If your profile age is under 18, TeoPateo asks you to use extra care with the AI coach and avoid sharing full names, contact details, or information you would not want a trusted adult to help you review.

## App Privacy Manifest Summary

The app target includes `PrivacyInfo.xcprivacy`.

The app declares:

- Health data and other user content collected only for app functionality when coach sharing sends data off-device.
- No tracking.
- `UserDefaults` access for app-only configuration using required-reason code `CA92.1`.

The bundled GRDB framework has its own privacy manifest.
