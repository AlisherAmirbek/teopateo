# History Timeline

## Goal

Let users inspect their saved check-ins, cravings, and slips so app insights feel trustworthy and recoverable.

The history should be useful for reflection without turning the app into a generic tracker.

## Current Gaps

- Daily check-ins persist but cannot be reviewed in the UI.
- Craving events persist but cannot be reviewed in the UI.
- There is no slip history.
- There is no unified timeline.
- Users cannot edit or delete accidental records.
- Insight cards do not link to supporting history.
- There is no weekly recap.

## MVP Scope

### Timeline

Create a chronological history screen showing:

- Craving events.
- Daily check-ins.
- Slip events when implemented.
- Plan changes when relevant.

Group entries by date.

### Entry Detail

Each entry should show the saved context:

- For cravings: time, duration, outcome, triggers, activity tried.
- For check-ins: mood, stress, confidence, smoked/no-smoke, focus note.
- For slips: time, cigarette count, triggers, note, recovery action.

### Edit And Delete

Allow basic correction:

- Delete accidental craving records.
- Delete accidental check-ins.
- Edit notes on check-ins and slips.

Keep destructive actions confirmed.

### Weekly Summary

Add a lightweight recap:

- Cravings logged.
- Cravings handled.
- Smoke-free check-in days.
- Top trigger.
- One suggested plan adjustment.

## Data Model Changes

Most existing records already have stable IDs and timestamps.

Add a timeline view model:

- `HistoryEntry`
- `HistoryEntryKind`
- `HistoryDayGroup`

If deleting records, repository methods should remove related trigger/activity rows through foreign keys.

## Store And Persistence

Recommended store methods:

- `historyEntries(range:)`
- `deleteCravingEvent(_:)`
- `deleteDailyCheckIn(_:)`
- `updateDailyCheckInNote(...)`
- `weeklyRecap(for:)`

## App Impact

- Add a History entry point from Today or Insights.
- `InsightsView` can link insight cards to filtered history.
- `CheckInView` can avoid duplicate same-day submissions by showing existing check-in state.

## Acceptance Criteria

- User can view persisted check-ins and cravings in reverse chronological order.
- User can inspect details for each record.
- User can delete accidental records with confirmation.
- Weekly recap is generated from persisted history.
- Insights can link to the history behind at least one pattern.
