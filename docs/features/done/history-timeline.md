# History Timeline

## Goal

Let users inspect their saved check-ins, cravings, and slips so app insights feel trustworthy and recoverable.

The history should be useful for reflection without turning the app into a generic tracker.

## Implemented Scope

- Added a full history sheet from Insights.
- Added a supporting-history link from the risk-window card.
- Added a unified reverse-chronological timeline for craving events, daily check-ins, and slips.
- Grouped timeline entries by date.
- Added entry detail views:
  - cravings show time, duration, outcome, triggers, intensity values, activity tried, and note when present
  - check-ins show mood, stress, confidence, smoking status, taper target, and slip note
  - slips show time, cigarette count, triggers, context, note, and recovery action
- Added confirmed delete actions for cravings, check-ins, and slips.
- Added note editing for check-ins and slips.
- Added weekly recap with:
  - cravings logged
  - cravings handled
  - smoke-free check-in days
  - top trigger
  - suggested plan adjustment

## Store And Persistence

No schema migration was needed because history records already have stable IDs and timestamps.

Implemented store and repository behavior:

- `historyEntries(range:)`
- `historyGroups`
- `weeklyRecap(for:)`
- `deleteCravingEvent(_:)`
- `deleteDailyCheckIn(_:)`
- `deleteSlipEvent(_:)`
- `updateDailyCheckInNote(...)`
- `updateSlipEventNotes(...)`

## App Impact

- `InsightsView` now opens the full history timeline.
- History details make calculated insights auditable by exposing the underlying saved records.
- Check-in and slip notes can be corrected without resetting the quit attempt.
- Destructive history actions require confirmation.

## Tests

- Store tests cover timeline grouping, weekly recap generation, note editing, range filtering, and delete behavior.

## Acceptance Criteria

- User can view persisted check-ins, cravings, and slips in reverse chronological order.
- User can inspect details for each record.
- User can delete accidental records with confirmation.
- User can edit check-in and slip notes.
- Weekly recap is generated from persisted history.
- Insights link to the supporting history.
