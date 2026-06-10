# Data Durability and Sync

## Goal

Protect the user's quit history — the emotional core of the product — from device loss, and decide whether progress follows the user across devices.

## The Risk

All data lives in on-device SQLite with no backup or sync. If the user replaces or loses their phone, their entire smoke-free streak, craving history, slips, and check-ins are gone. For a quit-smoking app, losing the streak is uniquely demoralizing and can end the quit attempt.

## Options

- **iCloud / CloudKit sync**: progress follows the user and survives device loss, with no separate account. Most aligned with a privacy-first, no-server-account design.
- **Export / import**: lighter-weight; lets users back up and restore manually. A reasonable minimum even if full sync is deferred.
- **Server-side storage**: only if accounts/identity are introduced for other reasons (e.g. coach personalization).

## Identity

- CloudKit sync needs no login. If server-side features are wanted later, Sign in with Apple is the low-friction path.

## Considerations

- Migration: the existing GRDB migration chain (v1–v8) must coexist with whatever sync model is chosen.
- Conflict handling for multi-device edits; last-writer-wins is likely acceptable for this data.
- If v1 stays local-only, tell users plainly that their data lives on this device.

## Acceptance Criteria

- A decision is recorded: CloudKit sync, export/import, or explicit local-only with user messaging.
- The chosen path is implemented and tested across a device restore.
- Data deletion and export are honored (ties to `privacy-policy-and-data-disclosure`).

## Open Questions

- Is cross-device continuity a launch requirement or a fast-follow?
