# ADR 0008: Flexible household membership and per-adult shares

- Status: Accepted
- Date: 2026-07-07

## Context

LootLog began as a strictly two-person app: two named members and a hard-coded
**50/50** split for every shared cost. Real households are not all couples — a
household may have one adult or several, plus dependents (kids) and pets — and
even two earners rarely split everything evenly. The name "LootLog" is now
historical; the model has to stop assuming exactly two equal adults without
breaking the events already on the wire.

## Decision

A household has **N members**, each with a role: `adult`, `dependent`, or `pet`
(`MemberSet {memberId, name, role, active, customSpriteSha256?,
descriptionText?}`). Only **adults** carry income, a vault, personal categories,
and paired devices; a single adult may pair any number of phones and desktops.
**Dependents** and **pets** are display-level party members with no ledger of
their own — all money remains household money.

Shared costs split by a per-adult **share table**
(`GroupShareSet {month, shares: {adultId: permille}}`), defaulting to an even
split. Every former 50/50 rule — group categories, shared personal purchases,
shared recurring expenses — generalizes to these shares, with **odd cents going
to the purchaser**. A **single-adult household is valid**: any approval that
requires "another adult" (pool withdrawals) is **auto-satisfied** when exactly
one adult exists.

Legacy `PetSet` events still reduce, now as pet members, so older histories
converge unchanged.

## Consequences

- The two-person, 50/50 assumption is removed from the domain; splits are data,
  keyed per month, and can change over time as incomes change.
- Dependents and pets enrich the party (and the game) without ever introducing a
  second ledger — the firewall between "who is shown" and "whose money it is"
  stays clean.
- Single-adult households are first-class: nothing that needs "a second adult"
  can deadlock.
- Backward compatibility is preserved by reducing legacy `PetSet` as pet
  members; no migration of existing event logs is required.
