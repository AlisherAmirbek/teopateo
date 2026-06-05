# TeoPateo Agent Notes

## Project Goal

TeoPateo is an iOS quit-smoking companion. The product goal is to help a user move from a vague intention to quit into a concrete daily plan, then support them during high-risk craving moments.

The strongest product idea is:

> A personal quit coach for the exact moment you are about to smoke.

The app should feel like a relapse-prevention system, not a generic habit tracker. It should help users identify smoking triggers, prepare a quit plan, handle cravings, track progress, and recover from slips without shame or unnecessary resets.

## Current Stage

The repository is a native MVP with persisted user data and a working coach integration path. It is still early product software, but the app is no longer just a hard-coded prototype.

Implemented today:

- SwiftUI app shell with tab navigation.
- Onboarding that generates a personalized quit plan from survey inputs.
- Today dashboard with mascot, progress facts, and a craving rescue entry point.
- Full-screen craving mode with a wall-clock 10-minute timer, replacement activities, motivational copy, local trigger selection, and craving/slip logging.
- Quit plan screen with quit date, taper/cold-turkey mode, trigger rules, replacement activities, reasons, and notification settings.
- Daily check-in screen with mood, stress, confidence, smoke/no-smoke choice, slip recovery notes, and daily focus.
- Insights screen with calculated risk windows, trigger contribution bars, heat map, history, weekly recap, and suggested plan adjustments.
- SQLite-backed persistence for quit plans, onboarding profile data, check-ins, cravings, slips, reasons, replacement activities, risky situations, coach chats, and notification settings.
- Local notification scheduling for plan reminders, post-meal prompts, evening check-ins, medication reminders, and calculated risk-window warnings.
- AI coach chat backed by a local/OpenRouter proxy, with streaming support and persisted chat history.
- Unit tests for planner logic, persistence, repository mutations, notification planning, coach streaming/failure paths, and store behavior.

Still rough or not production-complete:

- Production onboarding polish and broader UX validation.
- App Attest/server-side attestation verification for the coach proxy.
- Subscription/paywall behavior, if monetization is added.
- Longitudinal insights beyond the current local-history calculations.
- Production operations for the proxy, including deployment, monitoring, and secret rotation.
- UI automation coverage for the highest-risk flows.

## Repository Structure

```text
.
├── AGENTS.md
├── TeoPateo/
├── TeoPateo.xcodeproj/
├── docs/
├── images/
└── prototype/
```

### `docs/`

Project documentation and feature planning.

```text
docs/
├── CORE_IDEA.md
└── features/
    ├── waiting/
    └── done/
```

### `docs/CORE_IDEA.md`

Product strategy and feature scope. Treat this as the source of truth for the intended user experience and MVP boundaries.

### `TeoPateo/`

Native SwiftUI application source.

```text
TeoPateo/
├── TeoPateoApp.swift
├── ContentView.swift
├── Models/
├── Services/
├── Views/
└── Assets.xcassets/
```

Key files:

- `TeoPateoApp.swift`: App entry point. Creates the shared `TeoPateoStore`.
- `ContentView.swift`: Main tab navigation and craving-mode full-screen presentation.
- `Models/TeoPateoModels.swift`: Lightweight view models such as progress metrics, trigger rules, and coach messages.
- `Services/TeoPateoStore.swift`: Main-actor observable app state backed by `TeoPateoRepository`.
- `Services/SQLiteTeoPateoRepository.swift`: Durable local SQLite persistence.
- `Services/CoachService.swift`: Coach client implementations for the proxy and direct OpenRouter development path.
- `Views/TodayView.swift`: Home/dashboard screen and rescue button.
- `Views/CravingModeView.swift`: 10-minute craving intervention flow.
- `Views/PlanView.swift`: Quit plan UI.
- `Views/CheckInView.swift`: Daily check-in and slip recovery UI.
- `Views/InsightsView.swift`: Pattern insights UI.
- `Views/CoachView.swift`: Basic coach mock UI.
- `Views/Components.swift`: Shared SwiftUI components.
- `Views/Theme.swift`: Shared colors, font helper, and card styling.
- `Assets.xcassets/`: App image assets, including mascot artwork.

### `TeoPateo.xcodeproj/`

Xcode project for the native iOS app. The main scheme is `TeoPateo`.

Current project settings indicate:

- iOS deployment target: 15.0.
- Bundle identifier: `com.teopateo.TeoPateo`.
- Category: healthcare and fitness.
- Device family: iPhone and iPad.

### `docs/features/`

Markdown planning files for product features. Keep pending feature specs in `docs/features/waiting/` and move completed feature docs to `docs/features/done/`.

### `images/`

Source image files used by the prototype and mirrored in the Xcode asset catalog.

### `prototype/`

Temporary browser prototype for the UI. It predates the native SwiftUI implementation and is useful for comparing intended flows, but the SwiftUI app is now the primary implementation.

Prototype files:

- `index.html`: Prototype shell.
- `styles.css`: Browser prototype styling.
- `app.js`: Browser prototype behavior and mock state.
- `README.md`: Instructions for opening the prototype.

## Development Guidance

- Prefer extending the SwiftUI app under `TeoPateo/` over changing the browser prototype.
- Keep product behavior aligned with `docs/CORE_IDEA.md`.
- Preserve the calm, non-shaming tone. Slip recovery should be framed as learning, not failure.
- Use `TeoPateoStore` for short-term state while prototyping, but introduce persistence before treating any user-entered data as real product data.
- Avoid adding medical claims beyond high-level education. Medication guidance should direct users to a doctor, pharmacist, or quitline counselor.
- When adding functionality, replace hard-coded values with structured models before adding more static UI.
- Keep UI copy specific to quitting smoking and craving moments. The differentiator is intervention during the high-risk 10-minute window.
