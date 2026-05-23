# Deeper Insight Modeling

## Goal

Improve the insight engine so the app gives useful, defensible pattern observations from real user history.

Insights should help the user prepare for the next risky moment, not just display charts.

## Current Gaps

- Money saved uses a fixed cost per cigarette.
- Cigarettes avoided is estimated from smoke-free check-in days plus handled cravings.
- Smoke-free streak depends only on daily check-ins.
- There is no real "today's risk level."
- Risk windows only use craving event hours.
- Trigger contribution only uses craving trigger tags.
- Slip events are not modeled separately.
- Mood, stress, and confidence are not correlated with cravings or smoking.
- Plan adjustment suggestions cannot be applied.
- Heat map does not expose details for each day.
- The UI does not communicate when there is not enough data.

## MVP Scope

### Better Baseline Inputs

Use persisted plan/baseline data when available:

- Cigarettes per day before quitting.
- Cost per pack or cost per cigarette.
- Quit date or quit-attempt start date.
- Taper target when taper mode is enabled.

Until onboarding exists, these fields can be edited in Plan or Progress settings.

### Risk Level

Calculate a simple daily risk level from:

- Upcoming high-risk time windows.
- Recent craving frequency.
- Recent slips.
- Stress/confidence from latest check-in.
- Known trigger rules for the current day or context.

Output should be simple:

- Low.
- Moderate.
- High.

Each risk level should include one recommended action.

### Pattern Calculations

Add calculations for:

- Highest-risk time windows.
- Top craving triggers.
- Top slip triggers.
- Stress-associated craving days.
- Confidence trend.
- Craving outcome rate.
- Activity effectiveness when replacement activities are tracked.

### Insight Confidence

Use data thresholds before making strong claims.

Example:

- Fewer than 3 cravings: "Log a few cravings to reveal patterns."
- 3-7 cravings: "Early pattern."
- 8+ cravings: show stronger percentages.

### Actionable Suggestions

Every insight should point to a concrete next step:

- Add a trigger rule.
- Rehearse an existing rule.
- Pick a support contact.
- Prepare for a time window.
- Add a replacement activity.

## Data Model Changes

Likely dependencies:

- Baseline smoking fields from quit-plan builder.
- `SlipEvent`.
- Replacement activity completion records.
- Explicit craving outcomes.

Add a view model layer for calculated insight cards so views do not embed calculation rules.

## Store And Persistence

Recommended store/computation APIs:

- `todayRiskInsight`
- `progressSummary`
- `riskWindowInsights`
- `triggerInsights`
- `slipPatternInsights`
- `planAdjustmentSuggestions`

Keep calculations deterministic and unit-tested.

## App Impact

- `TodayView` can show today's risk level and one recommended action.
- `InsightsView` becomes a practical planning screen instead of only a report screen.
- `PlanView` can receive suggested changes from insights.
- `CheckInView` and `CravingModeView` become the main data sources for insights.

## Acceptance Criteria

- Dashboard shows today's risk level from real history.
- Money saved uses user-specific cost data when available.
- Cigarettes avoided uses baseline cigarettes/day when available.
- Insights distinguish handled cravings from slips.
- Insights include data-confidence copy for sparse history.
- At least one insight suggests a concrete plan action.
- Insight calculations have unit tests covering sparse, moderate, and rich-history cases.
