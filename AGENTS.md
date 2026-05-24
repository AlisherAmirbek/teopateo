# TeoPateo Agent Notes

## Project Goal

TeoPateo is an iOS quit-smoking companion. The product goal is to help a user move from a vague intention to quit into a concrete daily plan, then support them during high-risk craving moments.

The strongest product idea is:

> A personal quit coach for the exact moment you are about to smoke.

The app should feel like a relapse-prevention system, not a generic habit tracker. It should help users identify smoking triggers, prepare a quit plan, handle cravings, track progress, and recover from slips without shame or unnecessary resets.

## Current Stage

The repository is at an early native MVP prototype stage.

Implemented today:

- SwiftUI app shell with tab navigation.
- Today dashboard with mascot, progress facts, and a craving rescue entry point.
- Full-screen craving mode with a 10-minute timer, replacement activities, motivational copy, and trigger selection.
- Quit plan screen with quit date, taper/cold-turkey mode, trigger rules, replacement activities, reasons, and notification settings.
- Daily check-in screen with mood, stress, confidence, smoke/no-smoke choice, slip recovery notes, and daily focus.
- Insights screen with static risk patterns, trigger contribution bars, heat map, and suggested plan adjustment.
- Basic coach mock with quick prompts and canned responses.

Not implemented yet:

- Onboarding.
- Persistent storage.
- Real craving/check-in history.
- Calculated insights.
- Notification scheduling.
- Real AI coach integration.
- Production tests.

Most current app data is hard-coded or held in memory through `TeoPateoStore`.

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
- `Services/TeoPateoStore.swift`: Shared observable app state. Currently in-memory only.
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
