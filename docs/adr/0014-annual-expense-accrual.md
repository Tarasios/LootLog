# ADR 0014: Monthly accrual for annual recurring expenses

- Status: Accepted
- Date: 2026-07-07

## Context

Recurring expenses (ADR-era "equipment maintenance") were monthly only. Real
households have big annual bills — insurance, a domain renewal, a yearly game
subscription — that wreck a single month's budget if charged all at once and are
easy to forget. We want them smoothed across the year, reconciled exactly when
due, and computed at read time like everything else (ADR 0001), with no
scheduled jobs and no floating-point cents.

## Decision

`RecurringExpenseSet` gains `cadence: monthly | annual`, plus `dueDay`,
`dueMonth?` (for annual), `startMonth`, and `endMonth?`.

**Annual accrual.** An annual expense charges **1/12 monthly off the top**, with
the integer-cents **remainder landing in the due month so the twelve charges sum
exactly** to the real amount. The **due month** applies the real amount against
the accumulated reserve and surfaces any **shortfall or surplus**. Due dates are
shown to the user ("Rent — last day of month", "WoW — Feb 10").

Shared annual expenses split by the per-adult shares (ADR 0008) off the top;
personal ones come off that adult's budget. Variable annual expenses use
`VariableExpenseRecorded` to supply the actual, exactly as monthly variables do.

## Consequences

- Big annual bills stop being a once-a-year budget shock; the household reserves
  for them a month at a time and the due month simply reconciles.
- Integer-cents correctness is preserved: the remainder-in-the-due-month rule
  guarantees the twelve monthly accruals sum to the exact annual figure with no
  rounding drift.
- All of it derives in the reducer at read time — no cron, consistent with event
  sourcing — and it reuses the shares and variable-actual machinery rather than
  inventing new ones.
- In the game, annual expenses read naturally as "provisioning contracts with a
  countdown" (ADR 0011).
