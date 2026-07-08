# ADR 0011: Game-first product with a cosmetic-only rewards firewall

- Status: Accepted
- Date: 2026-07-07

Supersedes ADR 0003 (gamification as an optional skin).

## Context

ADR 0003 framed the dungeon adventure as an **optional** presentation skin
bolted onto a budgeting app. Product direction has changed: **the game is the
product.** Adventure mode is the primary, default experience on every platform;
Classic is the plain fallback. The app now leans on game mechanics — streaks,
celebrations, trophies, a homestead that grows — to drive the daily-logging and
monthly-ritual habits that make budgeting stick. This raises the stakes on the
one rule that must not bend: no game mechanic may ever move a cent.

## Decision

**Game-first.** Adventure mode is default and primary; Classic is always
available and shows identical numbers. Habit formation (streaks, celebrations,
an encouraging, never-shaming voice) and goals-orientation (savings quests
front-and-center; logging a purchase never more than two taps/keys away) are
core features, not polish.

**The firewall.** `lib/game/` maps `HouseholdState -> GameState` via
`lib/game/adapter.dart` (pure, tested) and may append **only cosmetic events**
(`CosmeticSet`, `GameRewardGranted`, sprite/description references). The money
reducer **ignores cosmetic events entirely**: a ledger with every cosmetic event
stripped must produce identical balances, and a test asserts exactly that from
the first rewards commit onward. No reward, streak, story beat, or homestead
threshold may alter any cent, limit, tithe, share, or allocation. **The
spoils/tithe math IS the combat math** — the game displays it and never
redefines it.

**Rewards and meta-progression, all cosmetic.** Defeating a quest boss grants a
trophy in the party's trophy hall; streaks earn cosmetic titles and badges;
every ritual completion gets a celebration. The war chest is visualized as the
**Homestead** — something built/cared for outside the dungeon that gains visible
stages as the real pool balance crosses configurable thresholds. All of it is
recorded as cosmetic events so it syncs like everything else, and all narrative
strings are data-driven asset files, not hardcoded.

## Consequences

- The domain and reducer keep zero game knowledge; Adventure and Classic can
  never disagree on money because both read the same derived state.
- Elevating the game to "the product" does not weaken the money guarantees — it
  *strengthens* the test that enforces them (the cosmetic-stripping firewall
  test is now load-bearing).
- Rewards are additive: new cosmetics are new cosmetic events / sprite
  references and can never change a ledger outcome.
- Because narrative and encouragement live in asset files, writers contribute
  without touching code.
