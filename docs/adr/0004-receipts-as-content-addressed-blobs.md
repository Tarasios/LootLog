# ADR 0004: Receipts as content-addressed blobs

- Status: Accepted
- Date: 2026-07-04

## Context

Purchases can carry receipt images or PDFs. These are large and binary, so they
do not belong inline in the event log, but they must still sync across devices
and hubs with the same convergence guarantees as everything else.

## Decision

Receipts are **not events**. They are **content-addressed blobs** stored at
`blobs/<sha256>` and referenced by `ReceiptAttached {purchaseId, sha256,
mimeType, sizeBytes}` / dereferenced by `ReceiptDetached`. Referenced blobs are
never deleted. Images are re-encoded on attach (JPEG ~85, max dimension
2000px); PDFs are stored as-is. Custom sprites (quests, pets, avatars) reuse the
**same blob pipeline** via their sha256 references.

## Consequences

- Content addressing makes blobs idempotent to transfer and store, matching the
  sync model (ADR 0002); the same content is stored once regardless of source.
- The event log stays small and text-only; large binaries move out of band via
  `PUT/GET /blobs/<sha256>`.
- Re-encoding on attach bounds blob size and normalizes formats. A 20MB cap is
  enforced at the hub.
- Because only references are removed and never the underlying content, no sync
  ordering can cause a dangling receipt.
