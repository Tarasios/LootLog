# LootLog Sync & Wire Protocol

LootLog converges devices over the local network with **no internet services,
servers, or accounts**. Any desktop build can host a **hub** (a small
`package:shelf` HTTP server); phones and the other desktop pair to it and sync.
Convergence needs no conflict resolution — see [ADR 0002](adr/0002-multi-hub-lan-sync.md).

Two properties do all the work:

- **Events are idempotent by `eventId`** (UUIDv7). Re-delivering an event — from
  a second hub, a re-sync, or a file import — is a no-op.
- **Blobs are content-addressed** at `blobs/<sha256>`. Duplicate uploads are
  harmless and every transfer is hash-verified.

## Roles

- A **hub** is a device hosting the HTTP endpoints below. It assigns a
  **per-hub monotonic `seq`** to every event it hosts (locally authored *or*
  pushed by a paired device), in arrival order.
- A **client** is any device syncing against one or more hubs. It keeps an
  **independent pull cursor per hub** and pushes/pulls each cycle. A desktop is
  usually both a hub and a client.

## Endpoints

All endpoints except `POST /pair` require `Authorization: Bearer <deviceToken>`.

### `POST /pair`

Request:

```json
{ "pairingSecret": "…", "deviceName": "Alice's phone" }
```

Response `200`:

```json
{ "hubId": "…", "deviceToken": "…" }
```

`403` on a bad pairing secret. The client stores `{hubId, baseUrl, deviceToken}`
and keys its pull cursor on `hubId`.

### `POST /events`

Idempotent batch append. Request:

```json
{ "events": [ { "eventId": "…", "type": "PurchaseAdded", "…": "…" } ] }
```

Each element is the canonical event envelope (`Event.toJson`). The hub appends
(ignoring ids it already holds), assigns any missing `seq`, and returns:

```json
{ "accepted": 12, "maxSeq": 431 }
```

### `GET /events?after=<seq>&limit=<n>`

Returns hosted events with `seq > after`, in `seq` order, up to `limit`
(default 500):

```json
{ "events": [ … ], "cursor": 431, "maxSeq": 431 }
```

- `cursor` — the `seq` of the last event in this page (or `after` when empty).
  The client advances its stored cursor to `cursor` and repeats until a short
  page signals it has caught up.
- `maxSeq` — the hub's high-water mark, i.e. how far behind the client still is.

Because `seq` is only ever handed to not-yet-sequenced events, an assigned `seq`
is stable forever and a cursor never misses or replays a row — even when an event
with an earlier `occurredAt` arrives after later events were already sequenced.

### `PUT /blobs/<sha256>`

Raw bytes, `≤ 20 MB`. The hub re-hashes the body and rejects a mismatch with
`400` (a corrupt or tampered blob). Idempotent: re-uploading identical bytes is a
no-op. `200` on success.

### `GET /blobs/<sha256>` · `HEAD /blobs/<sha256>`

`GET` returns the raw bytes or `404`. `HEAD` returns `200`/`404` so a client can
skip a `PUT` for a blob the hub already has.

## A sync cycle (client side)

For each paired hub, in order:

1. **Push events** — send `POST /events` with the events not yet pushed to this
   hub; mark them pushed on success.
2. **Push blobs** — for each referenced blob the hub lacks (`HEAD` → `404`),
   `PUT` it.
3. **Pull events** — loop `GET /events?after=<cursor>`, appending each page and
   advancing the cursor, until a short page.
4. **Pull blobs** — for each newly referenced blob missing locally, `GET` it.

Failures are **silent-but-visible**: an unreachable hub yields a per-hub error
surfaced on the status chip, never a thrown exception or a blocking dialog. The
next cycle retries.

## File fallback

When two devices can't reach a hub, the same events and blobs move as files:

- `.dbevents` — JSON Lines, one event envelope per line.
- `.dbevents.zip` — `events.jsonl` plus a `blobs/<sha256>` entry per referenced
  blob.

Import is idempotent (events by id, blobs by hash) and defensive: a malformed
file raises `ImportException` and a blob whose bytes don't match its name raises
`BlobIntegrityException`, both **before** anything is written to the log.

## Testing

`tool/e2e.sh` stands up two hubs and a third client over real loopback sockets
and asserts convergence across every scenario above — offline entries, shared and
group purchases, retroactive months, spoils, withdrawals, ransacks, receipt
propagation, surviving a hub outage, and file export/import parity.
