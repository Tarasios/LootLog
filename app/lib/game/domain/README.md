# lib/game/domain/

Pure Dart game logic for the guild-hall layer: no Flutter imports, fully unit
tested. Game state is a deterministic projection over game events, ordered by
`(occurredAt, eventId)`. Time comes from an injectable `Clock`; randomness from
a seeded RNG whose seed derives from the triggering event's id.

Nothing here may write ledger events except through the existing ledger API.

- `rewards/reward_engine.dart` — `RewardEngine.evaluate`: ledger events in,
  `RewardGranted` / `ChestGranted` / `StreakFreezeUsed` out (plus the
  `RewardClaimed` it writes when auto-spending a waiting freeze token or
  delivering a Standard partner's caravan). Run by `lib/data/game_rewards.dart`
  after every local ledger write and every sync merge. Ids are
  `<reasonCode>:<person>:<period>`, so re-runs and other devices never
  double-grant.
