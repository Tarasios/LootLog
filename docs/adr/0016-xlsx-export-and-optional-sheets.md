# ADR 0016: Offline .xlsx export and opt-in Google Sheets sync

- Status: Accepted
- Date: 2026-07-07

Relaxes the "no external services" invariant — narrowly, behind an interface,
off by default.

## Context

Users want their data in a spreadsheet: for their own analysis, for a tax
preparer, or to share a snapshot. DuoBudget's founding rule is **no external
services** — the whole app runs on the user's own devices. But "get my numbers
into a spreadsheet" has two very different flavours: a file the user saves
locally (no rule to relax), and live sync to a cloud service (a genuine
exception that must be contained so it can never become load-bearing).

## Decision

Two separate mechanisms:

**.xlsx export — fully offline, always available.** A pure-Dart xlsx writer
produces a workbook with sheets: Transactions, Monthly summary (per category
budgeted/spent/leftover), Members & income, Savings goals, Net worth, and
Recurring expenses. No network, no account, no service — it is just a file.

**Google Sheets sync — the ONLY permitted external service, and a deliberate,
contained relaxation of the no-external-services invariant.** It is:

- **OFF by default**, with explicit opt-in behind a clear *"your data leaves
  your local network"* warning;
- **user-supplied credentials** — the user brings their own;
- **isolated behind an interface**, so the app builds and fully functions with
  it absent, and **no other feature may depend on it**;
- **platform-guarded** like the OCR plugin.

## Consequences

- The common need (a spreadsheet) is met with zero compromise to the local-first
  guarantee — .xlsx is just a file and is always there.
- The one cloud exception is fenced: opt-in, warned, credential-BYO, isolated,
  optional to build, depended on by nothing. If it were deleted tomorrow the app
  would lose no other capability.
- Making the relaxation explicit here means future features can point at this
  ADR's fence when tempted to add a second external dependency — the answer is
  "no, and here's the standard that got Sheets in."
