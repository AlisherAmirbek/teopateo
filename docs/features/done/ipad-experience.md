# iPad Experience

## Goal

Deliver a deliberate iPad story instead of shipping a stretched iPhone layout.

## Decision

TeoPateo supports iPad for v1.

The project keeps `TARGETED_DEVICE_FAMILY = 1,2` and the existing iPad portrait and landscape orientations. The app should not be marketed as iPhone-only at launch.

## Implemented Scope

- Added shared adaptive screen metrics for regular-width iPad layouts.
- Centered general tab content on iPad with a bounded reading width instead of edge-to-edge stretched phone screens.
- Kept single-column reading surfaces narrower than two-column surfaces so body copy does not run too long on large iPads.
- Preserved the compact iPhone layout for phones, narrow iPad split-screen widths, and accessibility dynamic type sizes.
- Updated onboarding to use the shared bounded iPad shell for the first-run plan-building flow.
- Updated Today to use a two-column iPad layout:
  - quit action, plan suggestion, mascot, rescue entry, and safety resources in the primary column
  - weekly plan adherence, risk summary, and progress facts in the secondary column
- Updated craving mode to use a two-column iPad layout:
  - larger timer, motivation, and intensity controls in the primary column
  - rescue script, replacement actions, and trigger selection in the secondary column
- Expanded the craving-mode bottom outcome bar on iPad so the core outcomes are not stretched across the full screen.

## Reviewed Core Flows

- Onboarding plan-building flow at iPad width.
- Today dashboard at iPad width.
- Start craving rescue from Today.
- Craving-mode rescue state at iPad width.
- Craving-mode recovered and slipped logging states at iPad width.
- Other tabs through the shared adaptive screen shell.

## Validation

- Built successfully for an iPad simulator destination: `iPad (A16)`, iOS 26.5.
- Unit tests executed during the iPad simulator test run and passed.
- The full scheme test command did not complete because the UI test runner failed to initialize XCTest accessibility before app assertions ran. This was a simulator/XCTest initialization failure, not an app assertion failure.

## Acceptance Criteria

- A decision is recorded: proper iPad support.
- iPad support remains enabled in project settings.
- Core flows have dedicated iPad-width layouts instead of a stretched phone layout.
- Narrow widths and accessibility dynamic type fall back to the existing compact layout.
