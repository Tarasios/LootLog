import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/data/catalog_loader.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/decor/shop_rotation.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';

class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.contents);
  final String? contents;

  @override
  Future<ByteData> load(String key) async {
    final text = contents;
    if (text == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(text)));
  }
}

void main() {
  final catalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  GameCommandsService buildService(InMemoryGameEventStore store) =>
      GameCommandsService(
        store: store,
        actorId: 'alex',
        stamp: GameEventStamp(deviceId: 'device'),
        clock: FixedClock(DateTime.utc(2026, 10, 23, 12)),
        catalog: catalog,
      );

  test(
    'claiming the starter set and placing the bed are written to the store',
    () async {
      final store = InMemoryGameEventStore();
      final service = buildService(store);
      expect((await service.claimStarterSet()).accepted, isTrue);
      final placed = await service.placeItem(
        itemId: 'bed_simple',
        space: DecorSpace.room,
        column: 0,
        row: 0,
      );
      expect(placed.accepted, isTrue);
      final state = projectGameState(await store.all());
      expect(state.decor.placementsInRoom('alex'), hasLength(1));
    },
  );

  test('a double tap cannot claim the starter set twice', () async {
    final service = buildService(InMemoryGameEventStore());
    final results = await Future.wait([
      service.claimStarterSet(),
      service.claimStarterSet(),
    ]);
    expect(results.where((result) => result.accepted), hasLength(1));
  });

  test('run and runDecor share one queue', () async {
    final service = buildService(InMemoryGameEventStore());
    final results = await Future.wait([
      service.claimStarterSet(),
      service.run((commands) => commands.joinParty()),
      service.claimStarterSet(),
    ]);
    expect(results[0].accepted, isTrue);
    expect(results[2].accepted, isFalse);
  });

  group('loadDecorCatalog', () {
    test('reads the shipped catalogue', () async {
      final loaded = await loadDecorCatalog(
        _StringBundle(File('assets/game/catalog.json').readAsStringSync()),
      );
      expect(loaded.itemFor('bed_simple'), isNotNull);
    });

    test('returns the empty catalogue when the file is missing', () async {
      expect(
        await loadDecorCatalog(_StringBundle(null)),
        same(DecorCatalog.empty),
      );
    });

    test('returns the empty catalogue when the file is broken', () async {
      expect(
        await loadDecorCatalog(_StringBundle('{not json')),
        same(DecorCatalog.empty),
      );
    });
  });

  group('todaysShopProvider', () {
    test(
      'is empty until the catalogue loads, then offers the same six items all day',
      () async {
        final container = ProviderContainer(
          overrides: [
            gameClockProvider.overrideWithValue(
              FixedClock(DateTime.utc(2026, 10, 23, 12)),
            ),
            decorCatalogProvider.overrideWith((ref) => Future.value(catalog)),
          ],
        );
        addTearDown(container.dispose);
        expect(container.read(todaysShopProvider), isEmpty);
        await container.read(decorCatalogProvider.future);
        final shop = container.read(todaysShopProvider);
        expect(shop, isNotEmpty);
        expect(
          shop.map((item) => item.id),
          ShopRotation.forDay(
            catalog,
            GameDay.fromInstant(DateTime.utc(2026, 10, 23, 12)),
          ).map((item) => item.id),
        );
      },
    );
  });
}
