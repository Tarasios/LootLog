# ADR 0006: On-device, confirm-only OCR

- Status: Accepted
- Date: 2026-07-04

## Context

Receipt entry is tedious. OCR can speed it up, but DuoBudget has a hard
no-network, no-SaaS constraint, and we must never let a machine guess create
ledger entries silently.

## Decision

OCR is **Android-only** and **fully on-device**
(`google_mlkit_text_recognition`, bundled model, no network). The dependency is
platform-guarded so desktop builds do not pull it in. OCR is **confirm-only**:
it may prefill amount, date, and merchant, but may **never** create or commit
an event without explicit user confirmation of **at least the amount**.

The parsing heuristics live in `lib/data/ocr/receipt_parse.dart` as a **pure,
unit-tested function**, separate from the thin plugin wrapper that supplies raw
recognized text.

## Consequences

- No receipt data ever leaves the device.
- The pure parser is testable under TDD without any plugin or device.
- The confirm-only rule keeps the human in the loop, so a misread never
  silently corrupts the ledger.
- Desktop builds are unaffected by the Android-only ML Kit dependency.
