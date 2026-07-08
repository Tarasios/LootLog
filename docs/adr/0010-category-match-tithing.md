# ADR 0010: Category-match tithing for quest attacks

- Status: Accepted
- Date: 2026-07-07

Amends ADR 0005: quest funding is no longer universally untithed.

## Context

ADR 0005 made **every** quest attack untithed, on the reasoning that money
poured into a savings goal is already earmarked. In practice this let the tithe
be sidestepped entirely: convert-to-discretionary was tithed, but routing the
same leftover "through" a quest was not, so any leftover could dodge the war
chest by taking the quest path. We want to reward *aligned* saving (leftover
from a Food category feeding a Food-flavoured goal) without turning quests into a
tithe loophole, and main categories (ADR 0009) now give us a key to decide
alignment.

## Decision

Tithing on a quest attack depends on whether the **source category's main
category MATCHES the quest's `mainCategoryId`**:

- **Match → untithed.** The full leftover is damage to the quest boss.
- **No match → the source category's pool tithe applies.** The tithe portion
  goes to the war chest; the remainder is damage.

Canonical examples (also the domain tests):

- $100 Hygiene leftover, 50% tithe, attacking an **Entertainment** console quest
  → **$50 to the war chest + $50 damage** (no match).
- $100 Entertainment leftover, 20% tithe, attacking the same quest
  → **$100 damage, $0 tithe** (match).

The UI always shows the split **before** confirming. The dissolution tithe on
`QuestAbandoned` (ADR 0005) is unchanged.

## Consequences

- The convert-to-discretionary path and the non-matching quest path now tithe
  identically, so quests are no longer a way to avoid the war chest.
- Aligned saving is genuinely rewarded: matching leftover reaches the goal at
  full value, which is the behaviour we want to encourage.
- The rule is pure and testable: it depends only on the source category's main
  category, the quest's main category, and the source category's pool tithe —
  all already in derived state.
- This is the combat math the game displays (a mismatch shows the war-chest cut
  flying off as coins); the game never redefines it (ADR 0011).
