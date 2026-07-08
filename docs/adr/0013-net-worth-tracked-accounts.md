# ADR 0013: Net worth via tracked accounts, walled off from the budget

- Status: Accepted
- Date: 2026-07-07

## Context

Households want to see their whole financial picture — savings, investments,
debts — not just this month's spending. But that money is not budget money: it
must never fund a category, feed the war chest, or get pulled into spoils math.
We also have a hard no-network rule, so balances cannot be fetched from banks;
the user records them, and anything time-based (interest) is derived, not
scheduled.

## Decision

Add **tracked accounts**, entirely separate from the budget ledger:
`TrackedAccountSet {accountId, name, kind: savings | investment | debt, aprBps?,
accrualCadence?, updateCadence?, minPaymentCents?}`, plus
`AccountBalanceRecorded` and `AccountTransferRecorded`.

- **Savings / debt** current value = last recorded balance **+ interest accrued
  since**, derived at read time from `aprBps`/`accrualCadence` (no scheduled
  jobs, consistent with ADR 0001).
- **Investments** are never auto-changed; past their `updateCadence` they show a
  **"stale — update requested"** nudge.
- **Debt minimum payments** (`minPaymentCents`) surface automatically as
  recurring expenses so they enter the monthly plan — the one place tracked
  accounts touch the budget, and only as a reminder amount.

Tracked accounts **never enter category math.** They exist for the net-worth
screen and onboarding. The whole feature sits behind a "Show net worth" setting.

## Consequences

- Net worth is available without any bank integration and without violating the
  no-network rule; the user is the source of truth and interest is derived.
- The budget firewall holds: nothing about savings/investments/debt can alter a
  category, tithe, share, or the war chest — the sole crossover is surfacing a
  debt's minimum payment as a recurring expense.
- Investments never drift silently; a stale nudge keeps the number honest
  without pretending to know a value the app can't fetch.
