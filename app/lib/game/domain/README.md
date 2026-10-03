# lib/game/domain/

Pure Dart game logic for the guild-hall layer: no Flutter imports, fully unit
tested. Game state is a deterministic projection over game events, ordered by
`(occurredAt, eventId)`. Time comes from an injectable `Clock`; randomness from
a seeded RNG whose seed derives from the triggering event's id.

Nothing here may write ledger events except through the existing ledger API.
