# lib/game/domain/

Pure Dart game logic for the guild-hall layer: no Flutter imports, fully unit
tested. Game state is a deterministic projection over game events, ordered by
`(occurredAt, eventId)`. Time comes from an injectable `Clock`; randomness from
a seeded RNG whose seed derives from the triggering event's id.

Nothing here may write ledger events except through the existing ledger API.

- `game_event.dart`, `game_values.dart`, `game_state.dart`,
  `game_projection.dart` — the event schema, value types, the `GameState`
  read-model and the fold that builds it. The projection never rejects an
  event; it clamps and records a `GameWarning` instead (including
  `materialsCapped` when a credit would overflow the Storehouse, read as of
  the event's instant; trophies are never capped).
- `game_rng.dart` — `GameRng.forEvent(eventId)`: FNV-1a of the id seeding
  mulberry32 with exact 32-bit math, pinned against the JavaScript reference.
  Never use `dart:math` `Random` for game outcomes.
- `content.dart` — the shapes of the content tables (chests, buildings, gear
  slots, regions, seasonal bosses). The numbers are in `../config/balance.dart`.
- `hall_rules.dart` — read-side rules shared by commands and UI:
  `uncollectedProduction`, `collectableNow`, `fitInStorehouse`,
  `maxTierAllowed`.
- `commands/game_commands.dart` — `GameCommands(state, clock, actorId,
  stamp)`: every guild-hall action as a pure function returning a
  `GameCommandResult` (events to append, or a `GameRejection`). Anything
  random or time-dependent is computed once here and stored in the event:
  - `unlockPlot(i)` — gem price from `Balance.plotUnlockCost`.
  - `startBuilding(i, type)` — build on an empty plot or upgrade the same
    type by one tier; one of each building per hall; other buildings never
    outrank the Central Hall; upgrades wait for construction to finish; a
    producer's upgrade banks its production first (`MaterialsCollected`).
  - `collectMaterials(i)` — production since the last collection (old tier
    until an upgrade completes), trimmed to Storehouse room. Never gated on
    logging (rule 10).
  - `openChest(id)` / `claimReward(id)` — chests roll gems and maybe a freeze
    token (a token at the cap becomes gems); no materials (rule 9).
  - `upgradeGear(heroId:, slot:, gearType:)` — one tier at a time, never
    above the Forge; anyone may pay for anyone's gear.
  - `customizeHero(field:, value:)` — free, own hero.
  - `startExpedition(region)` / `resolveExpedition()` — one trip per hero;
    far regions open with the Central Hall; loot boosted by gear power,
    trimmed to Storehouse room, with a game-voice report.
  - `completeRitualStep(month, step)` — in order, once each, for a closed
    month at most `Balance.ritualOpenMonths` back.
  - `fightBoss(month, loggedDays:)` — after all four steps, once; simulated
    with the event-seeded RNG (gear power and the month's logged days help).
    The spoils chest is granted win or lose; a win adds a trophy.
  - `joinParty()` / `leaveParty()` — the household party (`kHouseholdPartyId`).
- `party_sync.dart` — `partyMembershipEvents`: the joins/leaves that bring the
  party in line with each adult's play mode. Run by the reward runner.
- `ledger_inputs.dart` — money-free facts read off the ledger:
  `loggedDaysInMonth`, `savingsAllocationMonths`.
- `rewards/reward_engine.dart` — `RewardEngine.evaluate`: ledger events in,
  `RewardGranted` / `ChestGranted` / `StreakFreezeUsed` out (plus the
  `RewardClaimed` it writes when auto-spending a waiting freeze token or
  delivering a Standard partner's caravan). Run by `lib/data/game_rewards.dart`
  after every local ledger write and every sync merge. Ids are
  `<reasonCode>:<person>:<period>`, so re-runs and other devices never
  double-grant.
- `rewards/month_end_rewards.dart` — `LedgerMonthEndRewards`, the engine's
  default `MonthEndRewards`: the gold chest (a personal category at or under
  its limit in a closed, well-logged month — a bonus only) and Vault
  milestones (quest goal shares, consecutive saving months — never amounts).
  Reads the reducer's `HouseholdState`; never writes the ledger.

The app-side wiring (store, `gameStateProvider`, `GameCommandsService`) is in
`lib/game/data/`.
