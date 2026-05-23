# Structured Slip Recovery

## Goal

Turn a smoking slip into useful plan data without resetting the quit attempt or shaming the user.

The app should help the user understand what happened, recover the next decision, and adjust the plan.

## Current Gaps

- Slip recovery is only shown inside the daily check-in.
- The slip note is free text only.
- There is no structured trigger capture for slips.
- There is no cigarettes-smoked count.
- There is no link from a craving slip into slip recovery.
- The app does not suggest a concrete next action after a slip.
- The plan is not updated from slip patterns.
- There is no explicit quit-attempt state.
- There is no option to intentionally restart a quit attempt.

## MVP Scope

### Slip Capture

Collect a short structured record:

- Date and time.
- Cigarettes smoked.
- Trigger tags.
- Mood or stress at the moment.
- Context, such as after meal, commute, alcohol, work stress, boredom, or social situation.
- What happened in the user's own words.
- What they want to do in the next 10 minutes.

The form should be short enough to use immediately after smoking.

### Recovery Guidance

After saving a slip, show a recovery card:

- "This does not erase the quit attempt."
- One immediate stabilizing action.
- One plan adjustment suggestion.
- One support option if available.

Avoid copy that implies failure, streak punishment, or starting over by default.

### Plan Adjustment

Use slip data to suggest:

- A new trigger rule.
- A stronger existing trigger rule.
- A replacement activity that matches the trigger.

For MVP, the app can show the suggestion and route to Plan. Later, it can apply the suggestion directly.

### Restart Option

Provide a separate, deliberate "restart quit attempt" action outside the normal slip flow.

Restarting should be explicit and should not happen automatically because the user smoked once.

## Data Model Changes

Add a `SlipEvent` model:

- `id`
- `occurredAt`
- `cigarettesSmoked`
- `selectedTriggers`
- `mood`
- `stress`
- `context`
- `note`
- `recoveryAction`
- `createdAt`
- `updatedAt`

Consider adding `QuitAttempt` later:

- `id`
- `startedAt`
- `quitDate`
- `endedAt`
- `restartReason`
- `isActive`

## Store And Persistence

Recommended store methods:

- `saveSlipEvent(...)`
- `recentSlipEvents(limit:)`
- `suggestRecoveryPlan(for:)`
- `restartQuitAttempt(...)`

Add SQLite tables for slips and slip triggers, following the existing craving-event persistence pattern.

## App Impact

- `CheckInView` can save structured slip details instead of only a note.
- `CravingModeView` can route to slip recovery when the user records smoking.
- `InsightsView` can identify slip triggers separately from handled-craving triggers.
- `PlanView` can show slip-driven plan suggestions.

## Acceptance Criteria

- User can record a slip without restarting progress.
- User can capture time, count, triggers, stress/mood, and note.
- Slip recovery shows one immediate next action after saving.
- Slip data persists locally.
- Slip events affect insights separately from handled cravings.
- The app never resets the quit attempt automatically after a slip.
