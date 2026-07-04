# ADR 0003: Gamification as a pure presentation skin

- Status: Accepted
- Date: 2026-07-04

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
