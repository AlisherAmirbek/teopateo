# App Store Privacy Answers

Use these answers for the App Store Connect App Privacy questionnaire for the current TeoPateo build.

## Tracking

- Does this app track users? No.
- Third-party tracking domains? No.

## Data Linked To The User

- Health and Fitness: Yes, linked to the user, not used for tracking.
- User Content / Other User Content: Yes, linked to the user, not used for tracking.

Use purpose: App Functionality.

Notes: Health-related quit-plan data and coach messages leave the device only when the user enables AI coach sharing and sends a coach request. Local-only quit data is otherwise stored on device.

## Data Not Linked To The User

- Crash Data: Yes, not linked to the user, not used for tracking.
- Diagnostics / Other Diagnostic Data: Yes, not linked to the user, not used for tracking.

Use purpose: App Functionality.

Notes: Release builds use Sentry for crash reporting and handled-error diagnostics. Sentry default personal information collection is disabled and quit-plan content, coach messages, and other user-entered health content are not intentionally attached to diagnostic events.

## Not Collected

- Contact Info.
- Financial Info.
- Location.
- Contacts.
- Browsing History.
- Search History.
- Identifiers, unless App Store Connect requires a Sentry installation identifier to be declared under diagnostics.
- Purchases, unless subscriptions or paid features are added later.
- Sensitive Info outside the health-related quit data already declared.

## App Review URLs

- Privacy Policy URL: https://teopateo.app/privacy/
- Support URL: https://teopateo.app/support/
