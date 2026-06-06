# In-App Safety and Medical Disclaimers

Status: Done

## Goal

Make TeoPateo's non-medical boundaries and crisis resources visible inside the app — not only inside the coach's hidden system prompt — and keep AI output safe and clearly labeled.

## Why

- The app is in Health & Fitness and gives quit-smoking guidance. Apple and users expect a clear "this is not medical advice" boundary.
- Crisis resources (988, 911, 1-800-QUIT-NOW) are currently surfaced only if the LLM happens to mention them. They should be reliably reachable.
- Coach replies are AI-generated and should be labeled as such.

## In-App Disclosure

- A visible, persistent "not medical care" disclaimer in onboarding and on the coach surface.
- A static, always-available crisis and quitline resource entry that does not depend on the LLM or on payment.
- Keep medication guidance pointed at a doctor, pharmacist, or quitline counselor, consistent with the project's existing guidance.

## AI Output Safety

- Label coach responses as AI-generated.
- Keep the proxy's safety system prompt (crisis routing, no diagnosis, no medication changes) and monitor for harmful output.
- Add a lightweight reporting path or logging so unsafe replies can be reviewed.

## Tone

- Preserve the calm, non-shaming voice. Safety messaging should reassure, not alarm.

## Acceptance Criteria

- A non-medical disclaimer is visible during onboarding and in the coach.
- Crisis and quitline resources are reachable without the AI and without payment (ties to `subscription-packaging`).
- Coach replies are visibly labeled as AI-generated.
- The safety system prompt is retained and monitored.

## Implementation Notes

- Added reusable SwiftUI safety components for the non-medical boundary and direct 988, 911, and 1-800-QUIT-NOW resource links.
- Surfaced the non-medical disclaimer during onboarding and on the coach surface; added the resource entry on Today and Coach.
- Labeled assistant coach messages as AI-generated and added a report action for unsafe replies.
- Persisted reported coach replies with a SQLite schema migration and logged report events through the `CoachSafety` logger category.
- Expanded the debug OpenRouter safety prompt with crisis routing, no diagnosis, and no medication-change guidance.
- Verified with `build_sim`, `plutil -lint`, and the simulator test suite.
