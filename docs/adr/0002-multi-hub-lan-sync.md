# ADR 0002: Multi-hub LAN sync with no conflict logic

- Status: Accepted
- Date: 2026-07-04

## Context

DuoBudget has no internet services, servers, or accounts. Two people on several
devices need their data to converge, with desktops acting as sync points on the
local network. A device might reach different desktops at different times, and
either desktop might be the one that is currently awake.

## Decision

Any desktop build can host a **hub** (`package:shelf`) on the LAN. A device may
be paired with **multiple hubs**, keeping an **independent pull cursor per
hub**. Every device syncs with every reachable paired hub each cycle.

Convergence relies on two properties rather than conflict resolution:
- **Events are idempotent by `eventId`** (UUIDv7), so re-delivering an event
  from a second hub is a no-op.
- **Blobs are content-addressed** (`blobs/<sha256>`), so duplicate uploads are
  harmless.

Hub endpoints: `POST /pair` -> `deviceToken`; `POST /events` (batch, idempotent,
assigns a per-hub monotonic `hub_seq`); `GET /events?after=<seq>`;
`PUT /blobs/<sha256>` (idempotent, hash-verified, 20MB cap); `GET
/blobs/<sha256>`. Pairing is via QR `{url, pairingSecret}`; tokens live in
`flutter_secure_storage`. A file-based fallback (`.dbevents` /
`.dbevents.zip`) supports offline transfer and is likewise idempotent on
import.

## Consequences

- No conflict-resolution code and no central authority: correctness follows
  from idempotency plus content addressing.
- Each hub assigns its own `hub_seq`; cursors are per-hub, so hubs never need to
  agree on ordering.
- Everything works offline indefinitely; sync failures are silent-but-visible
  via a status indicator, never blocking dialogs.
- Multi-hub duplication costs some redundant transfer, which we accept as the
  price of having no server.
