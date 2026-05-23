# Onboarding

## Goal

Capture the user's baseline smoking context and turn it into the first version of their quit plan.

## Inputs

- Cigarettes per day.
- Main triggers.
- Quit date.
- Quit approach.
- Reasons for quitting.

## App Impact

The onboarding flow populates the quit plan, initial dashboard metrics, trigger rules, replacement activities, and primary reason.

## Implemented Scope

- First-run full-screen onboarding presentation.
- Skip-for-now path from onboarding and Today.
- Baseline cigarettes/day and pack cost capture.
- Quit date and taper/cold-turkey approach capture.
- Trigger selection from a structured catalog.
- Primary quit reason capture.
- Plan creation through `TeoPateoStore.completeOnboarding`.
- Persisted onboarding completion state.
- Tests covering completion persistence and generated plan data.
