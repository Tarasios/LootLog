# ADR 0015: Vacation mode as a self-contained sub-budget

- Status: Accepted
- Date: 2026-07-07

## Context

A trip is a budget within a budget: it has its own categories (lodging, food,
activities), a fixed pot of money set aside for it, a start and end date, and
daily-allowance pacing — and it should not distort the household's normal
monthly budget while it runs. Households already save for trips as quests or
emergency funds; vacation mode should draw from that saved money, not create new
money.

## Decision

Add `VacationSet {vacationId, name, fundQuestId | emergencyFundId, startDate,
endDate, categories: [{name, limitCents}]}` and `VacationClosed`.

A vacation is a **self-contained sub-budget drawn from its fund** (a savings
quest or an emergency fund): per-category tracking, daily-allowance math, and
overspend warnings, all scoped to the trip. **Normal monthly budgets are
untouched** while it runs. Quick entry gains a **vacation charge target** while a
vacation is open (`VACATION(vacationId, categoryId)` joins the purchase charge
targets). **Closing returns any leftover to the source fund.** In the game it is
an "expedition abroad" side-floor.

## Consequences

- Trip spending is isolated: the monthly categories, spoils, and war chest are
  unaffected by vacation activity, so a two-week trip doesn't corrupt the month's
  numbers.
- No new money is created — a vacation only draws down an existing quest or
  emergency fund, and unused money flows back on close, so the ledger stays
  closed and auditable.
- Daily-allowance pacing and overspend warnings derive at read time from the
  trip's dates and its fund balance, consistent with the reducer-at-read-time
  rule.
