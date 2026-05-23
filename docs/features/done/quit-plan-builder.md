# Quit Plan Builder

## Goal

Turn the Plan tab from a mostly read-only summary into an editable quit-plan builder that helps the user prepare for the exact situations where they are most likely to smoke.

The plan should answer:

- When am I quitting?
- Am I tapering or stopping on the quit date?
- What baseline should progress use?
- What are my highest-risk triggers?
- What will I do instead when each trigger happens?
- Why does this quit attempt matter to me?
- What replacement actions can I use during a craving?

## Implemented Scope

- Quit date is rendered from persisted `QuitPlan.quitDate`.
- Relative quit-date copy is calculated from the current date.
- Quit date can be edited from the Plan tab.
- Taper/cold-turkey approach can be selected and persisted.
- Progress baseline can be edited:
  - baseline cigarettes per day
  - pack cost
- Taper mode shows the current persisted cigarette target.
- Trigger rules are rendered from store state.
- New trigger rules can be added from the Plan tab.
- Personal reasons can be added, marked primary, and deleted.
- Replacement activities can be reviewed and added with a category.
- Plan changes are persisted through `TeoPateoStore` and the SQLite repository.
- Tests cover plan, reason, activity, and persistence behavior.

## App Impact

- `PlanView` is now the primary editor for quit-plan data instead of a static plan summary.
- `TodayView` uses real quit-plan and progress data.
- `CravingModeView` draws substitute actions from saved replacement activities and trigger context.
- `InsightsView` can suggest plan adjustments from actual trigger and slip history.

## Key Code

- `PlanView`
- `TeoPateoStore`
- `QuitPlan`
- `TriggerRule`
- `UserReason`
- `ReplacementActivity`
- `SQLiteTeoPateoRepository`

## Acceptance Criteria

- The quit date shown in the Plan tab comes from persisted state and can be edited.
- Relative quit-date copy is calculated, not hard-coded.
- Approach selection persists.
- Baseline progress inputs persist.
- Trigger rules can be added.
- Personal reasons can be added, marked primary, and removed.
- Replacement activities can be added.
- The UI keeps a calm, non-shaming tone.
