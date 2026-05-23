# Replacement Activity Library

## Goal

Provide a practical library of fast substitute actions users can choose during cravings.

Activities should help the user get through the 10-minute risk window with options that match the moment.

## Current Gaps

- Craving mode has only three hard-coded actions.
- There is no activity library.
- Users cannot add custom replacement activities.
- Activities are not linked to triggers.
- Activity completion is not tracked.
- Insights cannot tell which activities help.
- There are no categories such as movement, breathing, social, distraction, journaling, or sensory reset.

## MVP Scope

### Activity Records

Each replacement activity should include:

- Title.
- Short instruction.
- Category.
- Suggested duration.
- Optional linked trigger.
- Enabled/disabled state.

Seed the app with practical defaults:

- Drink cold water.
- Walk outside.
- Brush teeth.
- Chew gum.
- Box breathing.
- Text support.
- Five-minute tidy.
- Write one sentence.

### Activity Selection

Craving mode should show:

- One activity matched to selected trigger when possible.
- One short physical activity.
- One calm/low-effort activity.
- One support activity when a contact exists.

The user should be able to mark which activity they tried.

### Custom Activities

Allow the user to add at least text-only custom activities:

- Title.
- Instruction.
- Category.

Custom activities should be usable in craving mode.

### Effectiveness Tracking

When a craving ends, save:

- Activity attempted.
- Whether the craving was handled without smoking.
- Optional helped/not-helped rating.

## Data Model Changes

Add `ReplacementActivity`:

- `id`
- `title`
- `instruction`
- `category`
- `durationSeconds`
- `linkedTrigger`
- `isEnabled`
- `createdAt`
- `updatedAt`

Add craving-event fields or join table:

- `attemptedActivityID`
- `activityHelpfulness`

## Store And Persistence

Recommended store methods:

- `replacementActivities`
- `addReplacementActivity(...)`
- `updateReplacementActivity(...)`
- `deleteReplacementActivity(_:)`
- `activitiesForCurrentCraving(triggers:)`
- `recordActivityAttempt(...)`

Add SQLite tables for replacement activities and activity attempts.

## App Impact

- `CravingModeView` becomes dynamic instead of hard-coded.
- `PlanView` can let users prepare trigger-specific substitute actions.
- `InsightsView` can show which activities correlate with handled cravings.

## Acceptance Criteria

- App ships with a default set of replacement activities.
- User can add and edit custom activities.
- Craving mode renders activities from persisted state.
- User can mark an activity as attempted during craving mode.
- Activity attempts are saved with craving events.
- Insights can eventually use activity outcomes to suggest better substitutes.
