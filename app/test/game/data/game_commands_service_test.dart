import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

const _me = 'u1';

/// Reads take a moment, so two unqueued commands would both read the state
/// before either appends.
class SlowReadStore implements GameEventStore {
  SlowReadStore(this.inner);

  final GameEventStore inner;

  @override
  Future<void> append(Iterable<GameEvent> events) => inner.append(events);

  @override
  Future<List<GameEvent>> all() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return inner.all();
  }

  @override
  Stream<List<GameEvent>> watchAll() => inner.watchAll();
}

/// Early October 2026: September is a closed month.
final DateTime _now = DateTime.utc(2026, 10, 3, 18);

void main() {
  late InMemoryGameEventStore store;
  var ids = 0;

  GameCommandsService service({
    List<Event> ledger = const [],
    GameCommandQueue? queue,
    GameEventStore? over,
  }) =>
      GameCommandsService(
        queue: queue,
        store: over ?? store,
        actorId: _me,
        clock: FixedClock(_now),
        stamp: GameEventStamp(
            deviceId: 'dev',
            newEventId: () => 'e${(ids++).toString().padLeft(5, '0')}'),
        ledger: () async => ledger,
      );

  Future<GameState> state() async => projectGameState(await store.all());

  setUp(() => store = InMemoryGameEventStore());
  tearDown(() => store.dispose());

  test('an accepted command is appended and visible to the next one', () async {
    final s = service();
    final r = await s.startBuilding(0, BuildingType.lumberyard);
    expect(r.accepted, isTrue);
    expect((await state()).hall.plots[0]!.building!.type,
        BuildingType.lumberyard);
    expect((await s.startBuilding(1, BuildingType.lumberyard)).rejection,
        GameRejection.buildingAlreadyInHall);
  });

  test('a rejected command appends nothing', () async {
    final r = await service().unlockPlot(3);
    expect(r.rejection, GameRejection.notEnoughGems);
    expect(await store.all(), isEmpty);
  });

  test('concurrent calls run one at a time (no double spend)', () async {
    await store.append([
      RewardGranted(
        eventId: 'a0',
        deviceId: 'dev',
        actorId: _me,
        occurredAt: _now.subtract(const Duration(hours: 1)),
        createdAt: _now,
        rewardId: 'r',
        kind: 'gems',
        gems: 25,
        materials: const MaterialBundle.empty(),
        tokens: 0,
        reasonCode: 'test',
        sourceLedgerEventIds: const [],
      ),
      RewardClaimed(
        eventId: 'a1',
        deviceId: 'dev',
        actorId: _me,
        occurredAt: _now.subtract(const Duration(hours: 1)),
        createdAt: _now,
        rewardId: 'r',
      ),
    ]);
    final s = service();
    final results = await Future.wait([s.unlockPlot(3), s.unlockPlot(4)]);
    // 25 gems buy the first plot (20) but not the second.
    expect(results.map((r) => r.accepted), [true, false]);
    expect((await state()).person(_me).gems, 5);
  });

  test('a rebuilt service shares the queue, so commands across both never race',
      () async {
    await store.append([
      RewardGranted(
        eventId: 'a0',
        deviceId: 'dev',
        actorId: _me,
        occurredAt: _now.subtract(const Duration(hours: 1)),
        createdAt: _now,
        rewardId: 'r',
        kind: 'gems',
        gems: 25,
        materials: const MaterialBundle.empty(),
        tokens: 0,
        reasonCode: 'test',
        sourceLedgerEventIds: const [],
      ),
      RewardClaimed(
        eventId: 'a1',
        deviceId: 'dev',
        actorId: _me,
        occurredAt: _now.subtract(const Duration(hours: 1)),
        createdAt: _now,
        rewardId: 'r',
      ),
    ]);
    final queue = GameCommandQueue();
    final slow = SlowReadStore(store);
    final before = service(queue: queue, over: slow);
    final rebuilt = service(queue: queue, over: slow);
    final results = await Future.wait([before.unlockPlot(3), rebuilt.unlockPlot(3)]);
    // The second sees the first's unlock: one plot, paid for once.
    expect(results.map((r) => r.accepted), [true, false]);
    expect((await state()).person(_me).gems, 5);
  });

  test('the provider keeps one queue across service rebuilds', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final queue = container.read(gameCommandQueueProvider);
    container.invalidate(gameCommandsServiceProvider);
    expect(container.read(gameCommandQueueProvider), same(queue));
  });

  test('the boss fight reads the month\'s logged days from the ledger',
      () async {
    const sept = Month(2026, 9);
    final ledger = [
      for (var d = 1; d <= 30; d++)
        PurchaseAdded(
          eventId: 'l$d',
          deviceId: 'dev',
          userId: _me,
          occurredAt: DateTime.utc(2026, 9, d, 18),
          createdAt: DateTime.utc(2026, 9, d, 18),
          purchaseId: 'p$d',
          target: const VaultCharge(),
          amountCents: 100,
        ),
    ];
    // Max gear: with every day logged the fight is always won.
    await store.append([
      for (final (i, slot) in ['weapon', 'armor', 'trinket'].indexed)
        GearUpgraded(
          eventId: 'g$i',
          deviceId: 'dev',
          actorId: _me,
          occurredAt: _now.subtract(const Duration(days: 1)),
          createdAt: _now,
          heroId: _me,
          slot: slot,
          gearType: 'x',
          tier: 5,
          cost: Loot.none,
        ),
    ]);
    final s = service(ledger: ledger);
    for (final step in RitualStep.values) {
      expect((await s.completeRitualStep(sept, step)).accepted, isTrue);
    }
    final r = await s.fightBoss(sept);
    expect(r.events.whereType<BossFightResolved>().single.won, isTrue);
    expect((await state()).person(_me).unopenedChests.values,
        [ChestType.spoils]);
  });

  group('providers', () {
    test('the game state follows the drift game log', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final built = Completer<GameState>();
      final sub = container.listen<AsyncValue<GameState>>(gameStateProvider,
          (_, next) {
        final v = next.value;
        if (v != null && v.hall.plots[0]?.building != null && !built.isCompleted) {
          built.complete(v);
        }
      }, fireImmediately: true);
      addTearDown(sub.close);

      final store = container.read(gameEventStoreProvider);
      final r = GameCommandsService(
        store: store,
        actorId: _me,
        clock: FixedClock(_now),
        stamp: const GameEventStamp(deviceId: 'dev'),
      );
      expect((await r.startBuilding(0, BuildingType.quarry)).accepted, isTrue);
      final s = await built.future.timeout(const Duration(seconds: 5));
      expect(s.hall.plots[0]!.building!.type, BuildingType.quarry);
    });
  });
}
