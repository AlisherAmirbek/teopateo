# Accessibility, Dark Mode, and Localization

Status: Done for native MVP implementation.

## Goal

Make TeoPateo usable for everyone and ready for more than one market. Health apps draw accessibility scrutiny, and the craving moment must work under stress.

## Accessibility

- Sliders now expose a label and value to VoiceOver. Extend the same pass to the rest: selectable tags should announce their selected state, buttons need clear labels, and the craving timer should be legible to assistive technology.
- Support Dynamic Type across screens; verify the craving and check-in flows at large text sizes.
- Run a full VoiceOver walkthrough of onboarding, craving mode, check-in, and the coach.

## Dark Mode

- The custom theme uses fixed colors. Verify legibility in dark mode, or explicitly lock the app to light mode and declare it.

## Localization

- User-facing strings are currently hardcoded English. Externalize copy so the app can be localized.
- Keep the quit-smoking-specific, non-shaming phrasing when translating; the craving and slip copy carry the product's voice.
- English-only is acceptable for a single-market v1 if the decision is explicit.

## Acceptance Criteria

- VoiceOver and Dynamic Type are verified on the core flows.
- Dark mode is supported or explicitly disabled.
- A localization decision is recorded; if deferred, strings are still externalized to make it cheap later.

## Implementation Notes

- Added adaptive light/dark theme colors instead of locking the app to light mode. Primary, success, danger, surface, text, muted, and divider colors now resolve against the active interface style.
- Improved Dynamic Type behavior in the core flows by replacing fixed-height text controls with minimum-height controls, allowing onboarding/check-in choices to wrap, scaling the craving timer and calendar day markers, and stacking high-risk paired actions at accessibility text sizes.
- Added VoiceOver state for selectable tags, onboarding choices, check-in smoke/no-smoke choices, coach chat selection, craving replacement activities, the craving timer, and heat-map dates.
- Added `TeoPateo/en.lproj/Localizable.strings` to the app target and externalized the current English UI copy into the bundle.
- Localization decision: English-only remains acceptable for v1, but the app now has an English localization table so future markets can translate static UI copy without rewriting views. User-entered content and generated quit-plan/history data remain stored as data and are not translated retroactively.
