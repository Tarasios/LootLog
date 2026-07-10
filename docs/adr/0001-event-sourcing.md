# ADR 0001: Event sourcing as the single source of truth

- Status: Accepted
- Date: 2026-07-04

## Context

LootLog is a two-person, local-first budget shared across multiple devices
that sync opportunistically over a LAN. We need corrections, an audit trail,
month-end behavior that is computed rather than scheduled, and — crucially —
conflict-free convergence when the same data arrives from more than one hub.

## Decision

All state changes are **immutable events** appended to a local `events` table.
Domain rows are never `UPDATE`d or `DELETE`d; corrections are made by appending
**compensating events**. All derived state is produced by a single pure
function `lib/domain/reducer.dart`: `List<Event> -> HouseholdState`. The UI,
sync, game skin, OCR, and receipt library never compute balances themselves.

Everything time-based (month close, grace-period defaults) is computed in the
reducer **at read time** — there are no scheduled jobs. Months are calendar
months in the household timezone, keyed by the user-editable `occurredAt`. Event
IDs are UUIDv7 so they are time-ordered.

## Consequences

- A full, replayable history and trivial audit trail.
- Idempotent merge by `eventId` makes multi-hub sync safe with no conflict
  resolution logic (see ADR 0002).
- The reducer must stay pure and total; all derivation is centralized and
  testable, and is developed under TDD.
- "Deleting" or "editing" is modeled as a new event, which users experience as
  a correction rather than destructive mutation.
