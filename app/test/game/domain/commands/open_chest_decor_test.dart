import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

var _eventCounter = 0;

GameEventStamp testStamp() => GameEventStamp(
      deviceId: 'device',
      newEventId: () => '01900000-0000-7000-a000-${(++_eventCounter).toString().padLeft(12, '0')}',
    );

final catalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync()) as Map<String, dynamic>);

ChestGranted chestGranted(ChestType chestType, String chestId) => ChestGranted(
      eventId: '01900000-0000-7000-8000-${(++_eventCounter).toString().padLeft(12, '0')}',
      deviceId: 'device',
      actorId: 'alex',
      occurredAt: DateTime.utc(2026, 10, 1),
      createdAt: DateTime.utc(2026, 10, 1),
      chestId: chestId,
      chestType: chestType,
      reasonCode: 'test.chest',
    );

GameState stateWithUnopenedChest(ChestType chestType, {required String chestId}) =>
    projectGameState([chestGranted(chestType, chestId)]);

void main() {
  test('opening a spoils chest adds a decoration with the chest id as its acquisition id', () {
    final commands = GameCommands(
      state: stateWithUnopenedChest(ChestType.spoils, chestId: 'ritual.spoils:alex:2026-09'),
      clock: FixedClock(DateTime.utc(2026, 10, 2)),
      actorId: 'alex',
      stamp: testStamp(),
      catalog: catalog,
    );
    final result = commands.openChest('ritual.spoils:alex:2026-09');
    expect(result.events.whereType<ChestOpened>(), hasLength(1));
    final acquired = result.events.whereType<ItemAcquired>().single;
    expect(acquired.acquisitionId, 'ritual.spoils:alex:2026-09');
    expect(acquired.source, DecorSource.chest);
  });

  test('without a catalogue, opening a chest behaves exactly as before', () {
    final commands = GameCommands(
      state: stateWithUnopenedChest(ChestType.wood, chestId: 'week.checkin:alex:2026-W43'),
      clock: FixedClock(DateTime.utc(2026, 10, 26)),
      actorId: 'alex',
      stamp: testStamp(),
    );
    final result = commands.openChest('week.checkin:alex:2026-W43');
    expect(result.events.single, isA<ChestOpened>());
  });

  test('a duplicate drop turns into extra gems and no item', () {
    // Own every dropped candidate first: open the chest once to learn the item,
    // then replay with that item already owned.
    final chestId = 'ritual.spoils:alex:2026-09';
    final first = GameCommands(
      state: stateWithUnopenedChest(ChestType.spoils, chestId: chestId),
      clock: FixedClock(DateTime.utc(2026, 10, 2)),
      actorId: 'alex',
      stamp: GameEventStamp(deviceId: 'device', newEventId: () => 'fixed-chest-event'),
      catalog: catalog,
    ).openChest(chestId);
    final dropped = first.events.whereType<ItemAcquired>().single;
    final ownedState = projectGameState([
      chestGranted(ChestType.spoils, chestId),
      ItemAcquired(
        eventId: '01900000-0000-7000-8000-ffffffffffff',
        deviceId: 'device',
        actorId: 'alex',
        occurredAt: DateTime.utc(2026, 9, 30),
        createdAt: DateTime.utc(2026, 9, 30),
        acquisitionId: 'earlier',
        itemId: dropped.itemId,
        source: DecorSource.shop,
        toTown: dropped.toTown,
      ),
    ]);
    final second = GameCommands(
      state: ownedState,
      clock: FixedClock(DateTime.utc(2026, 10, 2)),
      actorId: 'alex',
      stamp: GameEventStamp(deviceId: 'device', newEventId: () => 'fixed-chest-event'),
      catalog: catalog,
    ).openChest(chestId);
    expect(second.events.whereType<ItemAcquired>(), isEmpty);
    final plainGems = (first.events.first as ChestOpened).contents.gems;
    final withDuplicate = (second.events.single as ChestOpened).contents.gems;
    expect(withDuplicate, plainGems + Balance.duplicateDecorGems);
  });

  test('the gems and tokens are the same with or without a decoration drop', () {
    final chestId = 'ritual.spoils:alex:2026-09';
    GameCommandResult open(DecorCatalog withCatalog) => GameCommands(
          state: stateWithUnopenedChest(ChestType.spoils, chestId: chestId),
          clock: FixedClock(DateTime.utc(2026, 10, 2)),
          actorId: 'alex',
          stamp: GameEventStamp(deviceId: 'device', newEventId: () => 'same-chest-event'),
          catalog: withCatalog,
        ).openChest(chestId);

    final plain = open(DecorCatalog.empty);
    final withDrop = open(catalog);
    expect(withDrop.events.whereType<ItemAcquired>(), hasLength(1), reason: 'a real, non-duplicate drop');
    final plainLoot = (plain.events.single as ChestOpened).contents;
    final dropLoot = (withDrop.events.first as ChestOpened).contents;
    expect(dropLoot.gems, plainLoot.gems);
    expect(dropLoot.tokens, plainLoot.tokens);
  });
}
