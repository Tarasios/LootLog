import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';

final catalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  late InMemoryGameEventStore store;
  var ids = 0;

  GameCommandsService service(DecorCatalog withCatalog) => GameCommandsService(
        store: store,
        actorId: 'alex',
        clock: FixedClock(DateTime.utc(2026, 10, 3, 18)),
        stamp: GameEventStamp(
            deviceId: 'dev',
            newEventId: () => 'e${(ids++).toString().padLeft(5, '0')}'),
        catalog: withCatalog,
      );

  setUp(() async {
    store = InMemoryGameEventStore();
    await store.append([
      ChestGranted(
        eventId: 'g1',
        deviceId: 'dev',
        actorId: 'alex',
        occurredAt: DateTime.utc(2026, 10, 1),
        createdAt: DateTime.utc(2026, 10, 1),
        chestId: 'chest-1',
        chestType: ChestType.spoils,
        reasonCode: 'test.chest',
      ),
    ]);
  });
  tearDown(() => store.dispose());

  test('a chest is not opened before the decorations have loaded', () async {
    final result = await service(DecorCatalog.empty).openChest('chest-1');
    expect(result.rejection, GameRejection.catalogNotReady);
    expect((await store.all()).whereType<ChestOpened>(), isEmpty);
    // The chest is still there to open once the catalogue is ready.
    final later = await service(catalog).openChest('chest-1');
    expect(later.accepted, isTrue);
    expect(later.events.whereType<ItemAcquired>(), hasLength(1));
    expect(projectGameState(await store.all()).person('alex').unopenedChests,
        isEmpty);
  });
}
