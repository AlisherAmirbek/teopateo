# Quit Plan Builder

## Goal

Turn the Plan tab from a mostly read-only summary into an editable quit-plan builder that helps the user prepare for the exact situations where they are most likely to smoke.

The plan should answer:

- When am I quitting?
- Am I tapering or stopping on the quit date?
- What are my highest-risk triggers?
- What will I do instead when each trigger happens?
- Who can I contact when the urge is high?
- What risky situations should I prepare for?
- Why does this quit attempt matter to me?
- What medication or professional support do I want to discuss with a clinician, pharmacist, or quitline counselor?

## Current Gaps

- Quit date is visually hard-coded as `JUN 01`.
- The relative date copy, such as "11 days away", is hard-coded.
- Trigger rules are rendered from `TeoPateoStore`, but cannot be added, edited, disabled, deleted, or reordered.
- Support circle copy is hard-coded in `PlanView` instead of being rendered from `store.supportContacts`.
- Medication note copy is hard-coded in `PlanView`.
- Taper mode has explanatory copy, but no taper schedule, cigarette target, or daily reduction tracking.
- Risky-situation planning is missing.
- The "what I'll do instead" plan is only represented indirectly through trigger-rule copy.
- Personal reasons are stored, but not editable from the plan screen.

## MVP Scope

### Quit Date

- Render the date from `QuitPlan.quitDate`.
- Calculate the relative date label from the current date.
- Let the user edit the quit date.
- Keep the tone practical if the date is today or in the past, such as "Quit date is today" or "Choose a new date when you are ready to restart planning."

### Approach

- Keep the taper/cold-turkey segmented control.
- Persist the selected approach through the quit plan.
- For cold turkey, show preparation actions for substitutes, support alerts, and risky windows.
- For tapering, capture the current cigarettes-per-day baseline, target quit date, daily target, and reduction step.

### Taper Schedule

- Generate a simple daily target schedule from the baseline, quit date, and reduction settings.
- Show today's target clearly.
- Allow the user to mark whether they stayed within the target during check-in.
- Avoid shame-heavy language when the user misses a target; use it to adjust the plan.

### Trigger Rules

- Add create, edit, disable, delete, and reorder controls.
- Each rule should include:
  - Trigger.
  - "What I'll do instead" action.
  - Optional support contact.
  - Enabled/disabled state.
  - Sort order.
- Disabled rules should stay available for future use without affecting craving-mode suggestions or insights.

### Risky Situations

- Let users add planned high-risk contexts, such as drinking, driving, after meals, stressful workdays, or seeing friends who smoke.
- Each risky situation should include:
  - Situation name.
  - Expected time or context.
  - Prevention plan.
  - Backup action if the first plan fails.
  - Optional support contact.

### Support Circle

- Render support contacts from `store.supportContacts`.
- Allow adding, editing, and deleting contacts.
- Contact records should support at least:
  - Name.
  - Detail or relationship.
  - Preferred use, such as craving alert, evening check-in, or quitline.
- Future messaging can build on these records, but direct message sending is out of scope for this feature.

### Medication Note

- Store and render `QuitPlan.medicationNote`.
- Let the user edit the note as a personal reminder or question list.
- Keep medical copy high-level and direct the user to a doctor, pharmacist, or quitline counselor.

### Personal Reasons

- Render and edit `store.userReasons` from the Plan tab.
- Let users add, edit, delete, and reorder reasons.
- Use these reasons in craving mode as motivational copy.

## Data Model Changes

Extend `QuitPlan` and related models before expanding the UI.

Recommended additions:

- `QuitPlan.baselineCigarettesPerDay`
- `QuitPlan.taperTargetCigarettesPerDay`
- `QuitPlan.taperReductionStep`
- `QuitPlan.taperReductionIntervalDays`
- `TriggerRule.sortOrder`
- `TriggerRule.supportContactID`
- `RiskySituation`
- `RiskySituationPlan`

New risky-situation records should include stable identifiers and timestamps, following the persistence pattern used by check-ins, cravings, support contacts, and user reasons.

## Store And Persistence

`TeoPateoStore` should expose plan mutation methods instead of letting views own quit-plan logic.

Recommended store methods:

- `updateQuitDate(_:)`
- `updateQuitMode(_:)`
- `updateMedicationNote(_:)`
- `updateTaperSettings(...)`
- `addTriggerRule(...)`
- `updateTriggerRule(...)`
- `deleteTriggerRule(_:)`
- `moveTriggerRules(...)`
- `addSupportContact(...)`
- `updateSupportContact(...)`
- `deleteSupportContact(_:)`
- `addUserReason(...)`
- `updateUserReason(...)`
- `deleteUserReason(_:)`
- `moveUserReasons(...)`
- `addRiskySituation(...)`
- `updateRiskySituation(...)`
- `deleteRiskySituation(_:)`

Repository support should be added for any new risky-situation and taper fields so the plan survives app restarts.

## App Impact

- `PlanView` becomes the primary editor for quit-plan data instead of a static plan summary.
- `TodayView` should use the real quit date, current taper target, support data, and next risky situation when available.
- `CravingModeView` should draw substitute actions and support options from enabled trigger rules and personal reasons.
- `CheckInView` should optionally compare the day against the taper target.
- `InsightsView` should suggest plan adjustments that can be applied to editable trigger rules or risky situations.

## Acceptance Criteria

- The quit date shown in the Plan tab comes from persisted state and can be edited.
- Relative quit-date copy is calculated, not hard-coded.
- Trigger rules can be added, edited, disabled, deleted, and reordered.
- Support contacts are rendered from `store.supportContacts`, not hard-coded in `PlanView`.
- Medication note is rendered from `QuitPlan.medicationNote` and can be edited.
- Taper mode has a concrete daily target schedule.
- Risky situations can be created and reviewed from the Plan tab.
- Personal reasons can be edited from the Plan tab and reused in craving mode.
- The app keeps a calm, non-shaming tone when targets are missed or plans need adjustment.
