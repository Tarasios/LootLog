# ADR 0003: Gamification as a pure presentation skin

- Status: Superseded by [ADR 0011](0011-game-first-with-cosmetic-firewall.md)
- Date: 2026-07-04

> **Superseded (2026-07-07).** The product is now **game-first**: Adventure mode
> is the default, primary experience and Classic is the fallback — not an
> optional skin bolted onto a budgeting app. The cosmetic-only firewall
> described here still holds and is strengthened; see
> [ADR 0011](0011-game-first-with-cosmetic-firewall.md) for the current
> decision, [ADR 0012](0012-asset-degradation-and-text-mode.md) for the
> text-mode ladder, and [ADR 0009](0009-categories-and-main-categories.md) for
> the slice→category rename that also updates the mapping below. The historical
> decision is preserved unchanged.

## Context

DuoBudget offers an optional "dungeon adventure" presentation, but it must
remain a real budgeting tool. The game must never influence money, and users
must be able to switch it off and see identical numbers.

## Decision

Gamification is a **pure presentation skin**. `lib/game/adapter.dart` maps
`HouseholdState -> GameState` as a pure, tested function, and the domain has
**zero game knowledge**. The theme is toggleable (Classic / Adventure); both
render from the same providers with **identical numbers**. Only cosmetic events
(`CosmeticSet`, sprite references in `QuestSet`/`PetSet`) exist for the skin.

The mapping (slice → monster, quest → quest monster, vault → gold pouch, war
chest → pool, withdrawal → writ, ransack → banner, month → dungeon floor, etc.)
lives entirely in the adapter and adventure widgets. Pixel art renders with
`FilterQuality.none` at integer scales; missing assets degrade to labeled
placeholders and never crash.

## Consequences

- The domain and reducer never import game concepts, keeping them clean and
  independently testable.
- Because both themes read the same derived state, they can never disagree on
  money.
- New game cosmetics are additive (cosmetic events / sprite references) and
  cannot change ledger outcomes.
