# Local Persistence

## Goal

Create a mature local-first persistence layer so the app can reliably save the user's quit plan, check-ins, cravings, triggers, support context, and personal reasons on device.

## Recommended Approach

Use SQLite through GRDB.

The app should keep `TeoPateoStore` as the UI-facing state layer, but move durable reads and writes behind repositories. Views should not know about database tables or SQL.

```text
SwiftUI Views
-> TeoPateoStore
-> Repositories
-> Local SQLite database
```

This gives the MVP a real data foundation with migrations, indexes, queryable history, and clear ownership boundaries.

## Data To Persist

- Quit plan.
- Daily check-ins.
- Craving events.
- Trigger selections.
- Support contact.
- User reasons for quitting.
- Coach messages.

## Initial Tables

- `quit_plans`
- `trigger_rules`
- `daily_check_ins`
- `craving_events`
- `craving_event_triggers`
- `support_contacts`
- `user_reasons`
- `coach_messages`

## Record Shape

Durable records should use stable identifiers and timestamps.

- `id`
- `created_at`
- `updated_at`

Daily check-ins should capture:

- Date.
- Mood.
- Stress.
- Confidence.
- Smoke/no-smoke status.
- Daily focus note.
- Slip recovery note.

Craving events should capture:

- Start time.
- Completion time.
- Duration.
- Selected triggers.
- Whether the user completed the rescue flow.

## App Impact

The app should replace hard-coded and memory-only state with repository-backed state. Check-in submission and craving completion should create durable local records that other screens can query.
