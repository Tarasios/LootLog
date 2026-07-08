# ADR 0005: The spoils economy and quests

- Status: Accepted; amended by [ADR 0009](0009-categories-and-main-categories.md),
  [ADR 0010](0010-category-match-tithing.md), and
  [ADR 0008](0008-flexible-membership-and-shares.md)
- Date: 2026-07-04

> **Amended (2026-07-07).** The three-destination spoils ritual below still
> stands, but two rules changed and one term was renamed:
> - Quest attacks are **no longer universally untithed**. Tithing now depends on
>   whether the source category's main category matches the quest's — see
>   [ADR 0010](0010-category-match-tithing.md).
> - "Slice" is now **category** everywhere user-facing; the wire event
>   `BudgetSliceSet` is retained — see
>   [ADR 0009](0009-categories-and-main-categories.md).
> - The 50/50 split generalizes to a per-adult **share table** — see
>   [ADR 0008](0008-flexible-membership-and-shares.md).
>
> The historical decision is preserved unchanged; read the "untithed" and
> "slice" language below through those amendments.

## Context

We need month-end handling of leftover budget that is fair to two people,
supports shared savings goals, and cannot be gamed to avoid the household's
shared pool. Earlier designs used an "earmark" concept; it was ambiguous about
tithing and ownership.

## Decision

At month close (the "dividing the spoils" ritual), each **personal** slice's
leftover — `max(0, effectiveLimit − spent)` — is allocated by its owner via
`LeftoverAllocated` into one or more of:

1. **Carry in-slice 1:1** — raises next month's effective limit; stacks without
   cap.
2. **Attack a quest** — funds a savings-goal monster; **untithed**.
3. **Convert to discretionary** — enters the owner's vault **minus the slice's
   pool tithe** (per-slice %, floor rounding to the war chest, remainder to the
   user, summing exactly).

Group-slice leftovers and emergency contributions are automatic and read-only.
The ritual is interactive but **never blocking**: past the grace period
(default 7 days) the reducer applies the slice's configured default policy at
read time.

**Quests** (`QuestSet`) replace earmarks. They are funded **only** by spoils
allocations, and funding them is **untithed**. `QuestAbandoned` returns the
remaining balance to funders in proportion to contributions, **minus the
dissolution tithe** (default 10%) to the war chest — which is precisely what
stops quests from being used to dodge slice tithes.

## Consequences

- Three concrete, auditable destinations for leftover money, each an explicit
  event.
- The dissolution tithe closes the "park money in a quest, then abandon it"
  loophole.
- Because grace-period defaults are applied at read time, the month always
  closes even if a user never runs the ritual.
