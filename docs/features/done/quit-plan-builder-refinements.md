# Quit Plan Builder Refinements

## Goal

Make the completed MVP quit-plan builder usable as an ongoing plan editor instead of a mostly additive form.

## Implemented Scope

- Trigger rules can be edited, disabled, re-enabled, deleted, and reordered.
- Replacement activities can be edited, disabled, re-enabled, deleted, and reordered for craving-mode priority.
- Personal reasons can be edited and reordered, in addition to being added, marked primary, and deleted.
- Medication note can be edited from the Plan tab and persists with the quit plan.
- Taper mode exposes target, reduction step, and reduction interval controls.
- Taper mode generates upcoming daily targets from the stored plan.
- Check-in stores the taper target for that day and records whether the entry stayed within target.
- Risky situations are stored as separate records with context, prevention plan, backup action, and enable/disable state.
- Insights can apply a plan suggestion directly by creating a missing trigger rule or risky situation.

## App Impact

- `PlanView` now manages trigger rules, personal reasons, replacement activities, risky situations, taper settings, medication note, and reminders from one plan surface.
- `CheckInView` shows the current taper target and saves the target comparison with the daily check-in.
- `InsightsView` can apply a calculated plan adjustment instead of only deep-linking to the Plan tab.
- `TeoPateoStore` owns the mutation API for plan refinements so craving mode, insights, and notifications can read the same persisted plan state.
- SQLite schema version 5 adds taper check-in fields and risky-situation records.

## Tests

- Persistence tests cover risky situations and taper target check-in fields.
- Store tests cover trigger rule, reason, replacement activity, medication note, risky situation, taper schedule, check-in target, and insight-apply behavior.

## Acceptance Criteria

- The user can edit or remove stale trigger rules instead of accumulating bad rules.
- The user can disable plan items without deleting them.
- The user can prioritize replacement activities for craving mode.
- The user can edit or remove reasons in the Plan tab.
- The user can maintain a taper schedule and see whether check-ins stayed within target.
- The user can plan risky situations separately from trigger rules.
- Insights can write a useful plan adjustment back into the plan.
