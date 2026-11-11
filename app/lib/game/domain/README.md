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
  `workedMinutes`, `uncollectedProduction`, `collectableNow`,
  `shiftSummary`, `fitInStorehouse`, `maxTierAllowed`. Production follows
  the working shift: the whole household day on
  `GameState.townActiveDaysOf(personId)` (that town's own adult's logged
  days; freeze-covered days do not count, and a Standard caravan day extends
  nobody's shift), the first `Balance.shortShiftHours` of any other day.
- `town/town_ownership.dart` — one town per Adventure adult. Until the
  one-time `TownsSplit` (written by the reward engine, owner = the Adventure
  adult with the most `PlotUnlocked`/`BuildingStarted`/`MaterialsCollected`,
  ties to the smallest member id) the household shares one town; at the split
  it goes whole to the owner and everyone else starts from
  `HallState.starter()` plus `Balance.welcomeGrant`. Read a town with
  `GameState.townOf(personId)`; town events apply to their actor's town; the
  earliest split by `(occurredAt, eventId)` stands on every device.
- `town/trade_road.dart` — on each day two or more adults were active, every
  active Adventure adult gets a caravan (`RewardGranted`
  `trade.road:<who>:<day>:<neighbour>`) from every other active neighbour:
  `Balance.tradeRoadAmount` of that neighbour's busiest material (highest
  hourly rate, ties by enum order) scaled by its producer tier, or
  `Balance.caravanTradeBundle` from a Standard neighbour. Generated, never
  taken; one per neighbour so a late-syncing log tops the day up.
- `town/gifts.dart` — `GameCommands.sendGift(to, bundle)` moves materials to
  an Adventure neighbour's town (`GiftSent` stores what fits their
  Storehouse); the projection re-trims on a race so materials are always
  conserved and any overflow stays with the sender.
- `town/prosperity.dart` — each town's growth. `townProsperity` counts
  completed building tiers, town decorations on display (capped) and
  festivals held. The reward engine stores a new peak in `ProsperityReached`
  (the projection keeps the highest, so a decoration stored away never
  lowers it) and each tier the peak opens in `TierReached` (`TownTier`
  outpost, hamlet, village, town, city; thresholds `Balance.tierProsperity`),
  with its reward `tier:<who>:<tier>` (`Balance.tierRewards`). The village
  and beyond also wait for food in store (`town/food.dart`); a short town
  only waits, nothing is taken. Prosperity also counts districts bought
  (`Balance.prosperityPerDistrict`) and district building tiers. The daily gem cap is `Balance.dailyGemCapFor(tier)`.
- `town/districts.dart` — the district catalogue `kDistricts` (data: id,
  required tier, price, plot count, allowed building keys, tileset key):
  the outpost (the eleven hall plots, owned from the start), the farmland
  (hamlet, six plots, farm buildings only) and teasers not yet for sale.
  Plots are addressed by `PlotAddress(districtId, plotIndex)`; every older
  event, which names no district, means the outpost. Districts beyond it are
  bought with `DistrictPurchased` and built on with `DistrictBuildingStarted`
  (district and building by key, so a newer build's district is set aside,
  not hidden); their state is `HallState.districts`.
- `town/food.dart` — farms and orchards grow food by the hour under the
  working shift; harvesting (`FoodHarvested`) banks it up to the granary
  (`Balance.granaryFoodCapacityByTier`) into `HallState.food`. From the
  first harvest the engine writes `FoodConsumed {day, amount}` for each
  finished day: the need of the tier held that day
  (`Balance.populationByTier` × `Balance.foodPerResident`); a day is eaten
  once, a larger copy tops up the difference, the stores stop at zero.
  `foodSecure` (`Balance.foodSecureDays` of need) gates the village and
  beyond; a short town loses nothing.
- `town/farmland.dart` — the plans behind `buyDistrict`, `startFarmBuilding`
  (one granary per town; tiers follow the Central Hall; an upgrade banks
  food first) and `harvestFood`.
- `town/town_book.dart` — `townBook(state, personId, now)`: the UI's read
  model of a town's growth. `town/town_growth_lines.dart` holds its words
  (`assets/game/text/town_growth.json`).
- `commands/game_commands.dart` — `GameCommands(state, clock, actorId,
  stamp)`: every guild-hall action as a pure function returning a
  `GameCommandResult` (events to append, or a `GameRejection`). Anything
  random or time-dependent is computed once here and stored in the event:
  - `unlockPlot(i)` — gem price from `Balance.plotUnlockCost`.
  - `startBuilding(i, type)` — build on an empty plot or upgrade the same
    type by one tier; one of each building per town (the actor's own); other buildings never
    outrank the Central Hall; upgrades wait for construction to finish; a
    producer's upgrade banks its production first (`MaterialsCollected`),
    by the same working-shift rule as collecting.
  - `collectMaterials(i)` — production since the last collection (old tier
    until an upgrade completes, working shift per day), trimmed to
    Storehouse room. Collecting is never gated on logging (rule 10).
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
  Everything is bounded by `Balance.monthEndLookbackMonths`: a milestone is
  paid only when crossed inside that window (quest progress before it is
  reduced from the ledger as of the window's first month boundary), so the
  first run over an old ledger pays nothing for its history.
  Reads the reducer's `HouseholdState`; never writes the ledger.

The app-side wiring (store, `gameStateProvider`, `GameCommandsService`) is in
`lib/game/data/`.
