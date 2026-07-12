# Local Data Durability

## Goal

Keep the user's quit history durable on the current device while respecting App Store rules for health information.

## The Risk

Quit plans, cravings, slips, check-ins, and coach history are sensitive health-related data. Apple App Review Guideline 5.1.3(ii) says health-management apps may not store personal health information in iCloud, so the previous CloudKit backup implementation was removed before launch.

## Launch Decision

- User data is persisted in the app's on-device SQLite database.
- TeoPateo does not request iCloud or CloudKit entitlements and does not upload quit history to iCloud.
- The Privacy & Data screen plainly describes local storage and provides local deletion.
- A future user-controlled encrypted file export/import can be evaluated separately.

## Considerations

- The GRDB migration chain preserves existing on-device records across app updates.
- Removing CloudKit does not delete an existing local SQLite database.
- Cross-device continuity remains a post-launch product and compliance decision.

## Acceptance Criteria

- The app has no iCloud/CloudKit entitlement or runtime backup path.
- User-facing copy states that quit history remains on the device.
- Local persistence, migration, snapshot import, and deletion remain covered by tests.

## Follow-up

Design a compliant manual export/import flow if cross-device continuity becomes a priority.
