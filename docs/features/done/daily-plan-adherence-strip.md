# Daily Plan Adherence Strip

## Goal

Show a compact, visible weekly signal on Today so users can see whether each day matched the plan without opening insights or history.

The strip should reinforce daily plan adherence while keeping missed days calm and non-shaming.

## Implemented Scope

- Added a seven-day strip directly under the mascot on Today.
- Shows the current month and year.
- Shows Monday through Sunday with one circular day marker per day.
- Uses the app palette:
  - sage for achieved
  - peach for slight miss
  - warm red for missed
  - muted background for future or unlogged days
- Keeps the component compact so the rescue action remains close by.
- Added accessibility labels and identifiers for UI tests.

## Data And Rules

Daily status is derived from saved plan data:

- `achieved`: cigarettes smoked is within the saved target for that day.
- `slightMiss`: cigarettes smoked is just over target, within one cigarette or 25% of target.
- `missed`: cigarettes smoked is above the slight-miss allowance.
- `nil`: day is future or has no logged smoking/check-in data.

The calculation prefers the taper target saved on the check-in record, falling back to the current taper target for that date. This keeps historical days stable if the plan changes later.

Slip records are included as supporting cigarette counts for the day.

## Store And UI

Added:

- `DailyPlanAdherenceStatus`
- `DailyPlanAdherenceDay`
- `TeoPateoStore.currentWeekPlanAdherence`
- `TeoPateoStore.planAdherenceWeek(containing:)`
- `PlanWeekCard` in Today

## Tests

- Store tests cover Monday-to-Sunday week generation and achieved/slight-miss/missed classification.
- UI tests seed deterministic week data and verify the Today strip exposes all semantic states.

## Acceptance Criteria

- Today shows a weekly strip under the mascot.
- Each day can appear as achieved, slight miss, missed, or unlogged.
- Statuses are derived from persisted check-ins and slips, not hard-coded in the view.
- The strip is accessible and covered by UI tests.
