# App Store Submission Readiness

## Goal

Get TeoPateo through App Store Review and ready to ship, covering the assets, metadata, and disclosures Apple requires for a Health & Fitness app.

This is a launch gate rather than a single feature. Track each item to done before the first submission.

## App Icon

- Done. `AppIcon.appiconset` (1024×1024, no alpha) is wired up via `ASSETCATALOG_COMPILER_APPICON_NAME`. The build embeds the device icons and the App Store marketing icon.

## Store Assets

- Done. Native screenshot capture is automated for the current required 6.9" iPhone and 13" iPad classes; see `docs/app-store/screenshots.md`.
- Done. App name, subtitle, promotional text, full description, keyword list, URLs, copyright, and review notes are prepared in `docs/app-store/listing.md`.
- An optional app preview video; a short craving-rescue demo converts well.

## Metadata and Compliance

- Prepared. Category and current age-rating answers cover tobacco references, health/treatment content, and the AI coach; see `docs/app-store/compliance.md`.
- Done in the binary. Export compliance was audited and the app target declares exempt encryption (`ITSAppUsesNonExemptEncryption = false`).
- Prepared. Regulated-medical-device declaration is **No** while the product remains wellness support rather than a regulated diagnosis/treatment product.
- App Privacy answers must match the privacy manifest and policy (see `privacy-policy-and-data-disclosure`).

## Review Notes for Apple

- Explain the AI coach: it is an assistant, not medical care, with explicit non-diagnosis and crisis-routing behavior (see `in-app-safety-and-medical-disclaimers`).
- Provide a demo path that reaches craving mode and the coach without a real subscription, or reviewer credentials and notes (see `subscription-packaging`).
- Keep description copy educational; avoid promises of cessation outcomes (App Review 1.4.3 / 5.1.1).

## Acceptance Criteria

- App icon present and rendered (done).
- All required screenshots and metadata uploaded.
- Age rating and export compliance completed.
- Reviewer notes describe the coach and how to reach gated features.
- No medical or outcome claims beyond high-level education.

## Remaining Submission Work

- Upload the prepared screenshots and metadata to App Store Connect.
- Replace the temporary GitHub Issues support URL with a production page containing monitored contact information, as required by App Store Connect.
- Complete the App Store Connect privacy questionnaire from the existing privacy manifest/policy.
- Confirm the release build remains free of subscription gates before using the prepared review notes.
