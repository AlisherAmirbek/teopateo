# Support Circle Actions

## Goal

Make the support circle usable during cravings and recovery, without requiring the user to compose a message under stress.

Support should be practical, fast, and optional.

## Current Gaps

- Support contacts are persisted, but `PlanView` currently hard-codes support rows.
- There is no add/edit/delete UI for contacts outside the quit-plan builder scope.
- There are no contact methods such as phone number or message handle.
- There are no preset support messages.
- "Text Maya" in craving mode is not actionable.
- Quitline support is displayed as text only.
- There is no support action after a slip.
- There is no milestone sharing.

## MVP Scope

### Contact Records

Support contacts should support:

- Name.
- Relationship or detail.
- Phone number or message destination.
- Preferred support role, such as craving alert, evening check-in, quitline, or emergency backup.
- Optional default message.

The app can store contact details locally.

### Preset Messages

Provide editable message templates:

- "I am having a craving. Can you stay with me for 10 minutes?"
- "I slipped and need help getting back to the plan."
- "Can you check in with me tonight?"

Messages should be plain and not dramatic.

### Craving Mode Action

During craving mode, show one support action:

- Text primary support contact.
- Call quitline.
- Copy message if direct message sending is unavailable.

The app should not block the rescue flow if contact data is missing.

### Slip Recovery Action

After a slip, offer one calm support option:

- Text support contact.
- Call quitline.
- Save a request to follow up later.

## Platform Behavior

For MVP, use iOS system sheets where possible:

- `MessageUI` for SMS if available.
- `tel:` links for calls.
- Clipboard fallback for unsupported messaging paths.

Do not send messages automatically without user confirmation.

## Store And Persistence

Recommended additions:

- `SupportContact.phoneNumber`
- `SupportContact.preferredRole`
- `SupportContact.defaultMessage`
- `SupportMessageTemplate`

Recommended store methods:

- `addSupportContact(...)`
- `updateSupportContact(...)`
- `deleteSupportContact(_:)`
- `supportContactForCraving()`
- `supportMessageTemplate(for:)`

## App Impact

- `PlanView` renders persisted support contacts.
- `CravingModeView` can launch a support message or call.
- `StructuredSlipRecovery` can offer support after smoking.
- `TodayView` can show a support readiness cue if no contact is configured.

## Acceptance Criteria

- Support contacts are rendered from persisted data.
- User can configure at least one actionable contact method.
- Craving mode offers a one-tap support action when a contact exists.
- Quitline can be called from the app.
- Message content is user-confirmed before sending.
- If no contact exists, the app explains the missing setup without blocking craving rescue.
