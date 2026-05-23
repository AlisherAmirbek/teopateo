# Motivation Vault

## Goal

Give users a place to store and reuse personal reasons for quitting, especially inside craving mode.

Motivation should feel personal and concrete, not generic encouragement.

## Current Gaps

- `UserReason` exists and is persisted, but there is no dedicated UI to manage reasons.
- Craving mode hard-codes one reason.
- Plan can reference personal reasons only through the quit-plan builder scope.
- There are no rich motivation types such as photos, future-self notes, or family goals.
- The user cannot choose which reason appears during cravings.
- There is no rotation or resurfacing of saved reasons.

## MVP Scope

### Reason Management

Add a simple motivation section where the user can:

- Add a reason.
- Edit a reason.
- Delete a reason.
- Reorder reasons.
- Mark one reason as primary.

Reasons should stay short enough to be usable during a craving.

### Craving Mode Integration

Craving mode should show:

- The primary reason if set.
- Otherwise, the most recent saved reason.
- Otherwise, fallback non-personal copy.

Add a "Show another reason" action if more than one reason exists.

### Motivation Types

MVP can start with text reasons only.

Next layer can add:

- Future-self letter.
- Photo motivation.
- Health goal.
- Family goal.
- Financial goal.

## Data Model Changes

Extend `UserReason` with:

- `sortOrder`
- `isPrimary`
- `category`

Future rich motivation records may require separate attachment storage, but text-only MVP can reuse the current table with migration.

## Store And Persistence

Recommended store methods:

- `addUserReason(_:)`
- `updateUserReason(...)`
- `deleteUserReason(_:)`
- `moveUserReasons(...)`
- `setPrimaryUserReason(_:)`
- `reasonForCravingMode()`

## App Impact

- `PlanView` can expose reason editing, or this can live in a dedicated motivation screen.
- `CravingModeView` uses saved reasons instead of hard-coded copy.
- `TodayView` can surface the primary reason as part of daily preparation.

## Acceptance Criteria

- User can add, edit, delete, and reorder text reasons.
- User can choose a primary reason.
- Craving mode displays saved motivation copy.
- The app has a fallback when no reason exists.
- Reason changes persist across app launches.
