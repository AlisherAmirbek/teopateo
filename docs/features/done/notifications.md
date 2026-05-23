# Notifications

## Goal

Add opt-in local notifications for the moments most likely to protect the quit attempt.

## Implemented

- Morning plan reminders.
- Risk-window warnings generated from logged craving history.
- Post-meal reminders.
- Evening check-ins.
- Medication or nicotine replacement reminders, with copy that points users back to a clinician, pharmacist, or quitline counselor.
- Durable notification settings in local SQLite storage.
- A notification settings sheet from the Today bell and Quit Plan screen.
- Local scheduling through `UserNotifications`.

## Notes

Risk-window reminders only schedule after craving history has enough timestamped events to identify risky windows. The settings can be enabled earlier, and the schedule preview explains why no risk-window notification is pending yet.
