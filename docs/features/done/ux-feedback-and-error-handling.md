# UX Feedback And Error Handling

## Goal

Make the prototype feel reliable by showing clear feedback for saves, failures, selected states, and empty states.

The user should know when their quit data was saved and what to do when something goes wrong.

## Current Gaps

- `TeoPateoStore.persistenceError` exists but is not surfaced in the UI.
- Saving a check-in has no success feedback.
- Craving completion has no success feedback beyond dismissing the modal.
- Save failures are silent.
- Smoke/no-smoke buttons do not clearly show selected state.
- Check-in can be saved without choosing smoke/no-smoke.
- Check-in starts with demo-filled notes.
- Empty states are minimal.
- There is no duplicate same-day check-in handling.
- Persistence fallback to in-memory storage is invisible to the user.

## MVP Scope

### Save Feedback

Show lightweight confirmation after:

- Saving a check-in.
- Completing a craving.
- Saving a slip.
- Updating a plan item.

Use restrained UI such as inline status text or a small toast.

### Error Feedback

If persistence fails:

- Show a clear, non-technical message.
- Preserve the user's typed input when possible.
- Offer retry.

If the app falls back to in-memory storage, tell the user their data may not persist until the issue is fixed.

### Input States

Improve form behavior:

- Empty check-in notes by default.
- Clear selected state for smoke/no-smoke.
- Disable or confirm check-in save until smoke/no-smoke is selected.
- Highlight required fields gently.

### Empty States

Add useful empty states for:

- No cravings logged.
- No check-ins yet.
- No support contact.
- No personal reason.
- No insight history.

Each empty state should offer a specific next action.

### Duplicate Handling

If the user already checked in today:

- Show the existing check-in.
- Let them update it.
- Avoid creating confusing duplicate daily records unless they intentionally add another note.

## Store And Persistence

Recommended store additions:

- `lastSaveStatus`
- `clearPersistenceError()`
- `todayCheckIn`
- `upsertTodayCheckIn(...)`

Views should consume store state instead of each one inventing local save behavior.

## App Impact

- `CheckInView` becomes safer and less prototype-like.
- `CravingModeView` can confirm saved outcomes.
- `PlanView` can show update failures.
- `TodayView` can warn if local persistence is unavailable.

## Acceptance Criteria

- Check-in save success and failure are visible.
- Craving save success and failure are visible.
- `persistenceError` is surfaced in at least one global or screen-level UI.
- Smoke/no-smoke selection has a visible active state.
- Check-in notes start blank or from persisted same-day data, not demo copy.
- Same-day check-in update behavior is clear.
- Empty states include concrete next actions.
