# ADR 0007: The receipt library as a regenerable projection

- Status: Accepted
- Date: 2026-07-04

## Context

Users want their receipts as ordinary files they can browse and back up
outside the app, organized by year, category, and date. But files on disk are
easy to edit, move, or delete, and we cannot let that corrupt the ledger.

## Decision

The **receipt library (desktop only)** is a **regenerable projection, never a
source of truth**. The user picks a root folder; after every sync (and on
demand) the app mirrors receipt blobs into
`<root>/<year>/<slice name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>`
(sanitized, de-duplicated with `_2` suffixes), derived from each receipt's
purchase.

Rebuilding from scratch must produce **identical content**. Any user edits
inside the folder are **ignored and overwritten** on the next projection. The
path/naming logic is developed under TDD.

## Consequences

- The folder is disposable and reproducible; losing or scrambling it costs
  nothing because it is rebuilt from blobs plus derived state.
- Users get a clean, human-organized archive without the ledger ever depending
  on the filesystem layout.
- Deterministic naming (with `_2` de-duplication) means the projection is
  stable across runs and machines.
