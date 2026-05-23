# Craving Mode Recovery Path

## Goal

Make craving mode a complete intervention flow for the exact high-risk moment, not only a success logger.

The user should be able to enter craving mode, choose relevant support, ride out the urge, and record what actually happened without shame.

Full craving mode is part of the paid package. Free users should see a calm locked-state screen with upgrade context and still have access to quitline or professional support prompts.

## Current Gaps

- The only completion outcome is "I got through it."
- Closing craving mode records nothing.
- There is no "I smoked" or "I slipped" path from the craving flow.
- Trigger options are hard-coded in `CravingModeView`.
- Replacement activities are hard-coded.
- Personal motivation copy is hard-coded.
- "Text Maya" is display-only.
- There is no craving intensity before or after the intervention.
- The app does not distinguish between a completed 10-minute rescue and an early tap on the success button.
- There is no post-craving reflection.

## MVP Scope

### Entry State

- Set `startedAt` when craving mode is opened.
- Reset selected triggers for each new craving unless the app has a deliberate reason to preselect them.
- Ask for a quick intensity rating, such as 1-10, before the timer starts.
- Show the user's saved reason for quitting when available.

### Intervention Steps

- Keep the 10-minute timer as the main anchor.
- Add one guided breathing card.
- Show replacement activities from the saved activity library or enabled trigger rules.
- Show one support option from the support circle when available.
- Keep all copy calm and direct; the user is in a high-risk moment.

### Outcomes

Support at least three outcomes:

- `completed_without_smoking`: user got through the craving.
- `smoked_after_craving`: user smoked during or after the craving.
- `dismissed_without_outcome`: user left craving mode without recording an outcome.

The first two should persist explicit records. The dismissed state can be recorded later if needed, but the app should avoid treating silent dismissal as success.

### Post-Craving Reflection

After success or slip, collect lightweight context:

- Final intensity rating.
- Trigger tags.
- What helped most.
- Optional note.

For slip outcome, route the user into the structured slip recovery flow.

## Data Model Changes

Extend `CravingEvent` with:

- `outcome`
- `initialIntensity`
- `finalIntensity`
- `helpedActivityID`
- `supportContactID`
- `reflectionNote`
- `dismissedAt`

`completedWithoutSmoking` can remain during migration, but new code should prefer an explicit outcome enum so future states do not collapse into a boolean.

## Store And Persistence

Recommended store methods:

- `startCravingSession()`
- `updateCurrentCravingTriggers(_:)`
- `completeCravingWithoutSmoking(...)`
- `completeCravingWithSlip(...)`
- `dismissCravingSession()`

Persistence should support explicit craving outcomes and preserve old records through a migration.

## App Impact

- `TodayView` remains the main rescue entry point.
- `CravingModeView` becomes the strongest paid product flow.
- `InsightsView` can compare handled cravings, slipped cravings, triggers, and activity effectiveness.
- `CheckInView` can reference craving events from the day instead of asking the user to reconstruct everything later.

## Acceptance Criteria

- Starting craving mode creates a fresh session state.
- User can record both "I got through it" and "I smoked" outcomes.
- Trigger selections and intensity ratings persist with the craving event.
- Craving mode uses saved user reasons when available.
- Craving mode can show saved replacement activities.
- A slip outcome routes into structured, non-shaming recovery.
- Dashboard and insights do not count dismissed craving mode sessions as handled cravings.
