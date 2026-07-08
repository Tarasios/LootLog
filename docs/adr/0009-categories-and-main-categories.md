# ADR 0009: Budget categories and main categories (the "slice" rename)

- Status: Accepted
- Date: 2026-07-07

Supersedes the user-facing "slice" vocabulary of ADR 0005 (the wire event names
are retained).

## Context

The domain called a budget line a **"slice."** The word is jargon: it reads
oddly in Classic mode (which is supposed to use plain language only), it has no
natural grouping, and it gives reports nothing to aggregate on. We also want a
monthly pie chart of spending and a clean way to decide quest-tithe matches —
both of which need a coarser grouping than the individual line.

## Decision

A budget line is a **category** everywhere users can see it. The word **"slice"
never appears in UI or docs.** The internal event name `BudgetSliceSet` is kept
**only for wire compatibility** — old events keep reducing and syncing — but it
is a category in every human-facing surface.

Each category belongs to a **main category**
(`MainCategorySet {id, name, colorArgb, sortOrder}`), with defaults Housing,
Food, Transport, Health, Entertainment, Pets, Savings, and Misc. Main-category
**colors drive reports** (a monthly pie chart of spend by main category) and are
the key for **quest-tithe matching** (see ADR 0010). A category is still either
**personal** (one adult) or **group** (household), and the personal/group,
limit, emergency-contribution, and tax rules are otherwise unchanged.

## Consequences

- Classic mode can honour its "plain language only" rule; "slice" joins
  "tithe," "spoils," and "dissolution" as internal terms the glossary maps away.
- Reports gain a stable grouping and palette: main-category colors are the
  single source for the spend pie chart.
- Quest-tithe matching has a well-defined key (the main category), enabling the
  category-match rule in ADR 0010.
- No event-log migration: `BudgetSliceSet` and friends remain on the wire, so
  existing and in-flight events converge exactly as before.
