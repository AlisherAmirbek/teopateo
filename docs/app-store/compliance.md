# TeoPateo App Store Compliance Answers

These answers reflect the July 12, 2026 codebase and Apple questionnaire definitions. Re-run the audit if networking, medical claims, community features, or third-party SDKs change.

## Age Rating Questionnaire

Recommended answers:

| Questionnaire item | Answer | Basis |
| --- | --- | --- |
| Parental controls | No | The app has no parent/guardian controls. |
| Age assurance | No | Onboarding records a self-reported age but does not verify age or call the Declared Age Range API. |
| Unrestricted web access | No | The app does not include a general-purpose browser. External support links are fixed destinations. |
| User-generated content | No | User notes and coach messages are private; they are not broadly distributed to other users. |
| Social media | No | There is no feed, sharing, following, or interaction with other users. |
| Messaging and chat | No | The coach is an AI service. Users cannot communicate with one another, which is Apple's definition of this capability. |
| Advertising | No | There are no ads. |
| Alcohol, tobacco, or drug use or references | Frequent | Smoking, cigarettes, nicotine triggers, and slips are central throughout the app. The references are cessation-oriented and do not encourage use. |
| Medical or treatment information | Infrequent | The app includes limited quitline, crisis, medication-professional, and safety guidance, but no diagnosis or individualized treatment. |
| Health or wellness topics | Yes | Quit planning, craving coping, check-ins, and lifestyle replacement activities are core content. |
| All other mature themes, sexuality, violence, weapons, gambling, contests, and loot boxes | None / No | None are present in the intended experience. |

Expected result: Apple's questionnaire determines the final rating and regional variants. Under Apple's current global table, **frequent tobacco references can produce an 18+ rating**, while infrequent medical information can produce 13+. Do not understate the tobacco frequency simply because the context is cessation.

AI-specific note: there is no standalone “AI chat” age-rating switch in the current questionnaire. Answer **Messaging and chat: No** because Apple defines that capability as direct user-to-user communication. The AI behavior still needs to be disclosed in review notes, privacy answers, and the in-app consent/safety UI.

## Regulated Medical Device

- **Is this app a regulated medical device in any country or region?** No.

Basis: TeoPateo is wellness and behavioral support. It has no FDA clearance or registration, CE mark, UKCA mark, EU/UK medical-device self-certification, diagnostic function, treatment prescription, medication dosing, or regulated-device accessory behavior.

This is a product-scope declaration, not a substitute for legal advice. Reassess before adding diagnostic claims, treatment recommendations, medication decision support, clinical monitoring, or hardware integrations.

## Export Compliance

- **Does the app use encryption?** Yes — standard HTTPS/TLS through Apple's networking stack.
- **Does the app implement proprietary or non-standard cryptography?** No.
- **Does the app implement encryption algorithms outside those provided by Apple's operating system?** No, based on the current source and linked SDK audit.
- **Is export-compliance documentation expected?** No; the current use is exempt / does not require documents in App Store Connect.
- **Info.plist declaration:** `ITSAppUsesNonExemptEncryption = false`.

The app target now emits that key for Debug and Release. Re-audit if a dependency adds its own cryptographic implementation, VPN/security features, encrypted custom storage, or non-Apple TLS/crypto libraries.

## App Privacy Cross-Check

- Health data and other user content: collected for app functionality only when the user enables and uses AI coach sharing.
- Diagnostics/crash data: collected for app functionality in release builds through Sentry, without user-entered quit content.
- Tracking: No.
- Data used for advertising: No.
- Local quit data is not synced to iCloud.

The App Store Connect privacy answers must stay aligned with `TeoPateo/PrivacyInfo.xcprivacy` and `docs/PRIVACY_POLICY.md`.

## Submission References

- Apple regulated medical-device declaration: https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status
- Apple export compliance overview: https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance
- Apple encryption Info.plist key: https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- Apple age-rating definitions: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
- Apple screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
