/// Riverpod wiring for the guild hall: the game event store, the projected
/// [GameState], and the command service the hall UI writes through.
///
/// - [gameEventStoreProvider]: the on-device game log ([DriftGameEventStore]
///   over the app database's `game_events` table).
/// - [gameStateProvider]: the projection, re-emitted after every append
///   (local commands, reward runs, sync merges).
/// - [gameClockProvider]: the game's clock (overridden in tests).
/// - [decorCatalogProvider] / [todaysShopProvider]: the decoration catalogue
///   and today's shop rotation.
/// - [gameCommandsServiceProvider]: this device's adult's
///   [GameCommandsService] (null until local setup exists).
///
/// Everything here is behind the Adventure gate by convention: only game UI
/// reads these providers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../domain/clock.dart';
import '../domain/decor/catalog.dart';
import '../domain/decor/shop_rotation.dart';
import '../domain/game_event_stamp.dart';
import '../domain/game_event_store.dart';
import '../domain/game_projection.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import 'catalog_loader.dart';
import 'drift_game_event_store.dart';
import 'game_commands_service.dart';

export 'game_commands_service.dart';

/// The game's "now": the device's wall clock in the app, a `FixedClock` in
/// tests. The command service and the hall UI read the same clock, so a
/// countdown shown on screen and the command it gates always agree.
final gameClockProvider = Provider<Clock>((ref) => const SystemClock());

/// The game event log on this device.
final gameEventStoreProvider = Provider<GameEventStore>(
  (ref) => DriftGameEventStore(ref.watch(appDatabaseProvider).gameEventsDao),
  dependencies: [appDatabaseProvider],
);

/// The guild-hall [GameState], projected from the whole log on every change.
final gameStateProvider = StreamProvider<GameState>(
  (ref) => ref.watch(gameEventStoreProvider).watchAll().map(projectGameState),
  dependencies: [gameEventStoreProvider],
);

/// The command service for this device's adult, or null before setup.
final gameCommandsServiceProvider = Provider<GameCommandsService?>(
  (ref) {
    final setup = ref.watch(localSetupProvider).value;
    if (setup == null) return null;
    final db = ref.watch(appDatabaseProvider);
    return GameCommandsService(
      store: ref.watch(gameEventStoreProvider),
      actorId: setup.meUserId,
      clock: ref.watch(gameClockProvider),
      stamp: GameEventStamp(deviceId: ref.watch(deviceIdProvider)),
      ledger: db.eventsDao.allEvents,
      catalog: ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty,
    );
  },
  dependencies: [
    localSetupProvider,
    appDatabaseProvider,
    gameEventStoreProvider,
    deviceIdProvider,
    gameClockProvider,
    decorCatalogProvider,
  ],
);

/// The decoration catalogue (empty until loaded, or if the file is broken).
final decorCatalogProvider = FutureProvider<DecorCatalog>(
  (ref) => loadDecorCatalog(),
);

/// Today's shop items, the same on every device. Empty until the catalogue
/// loads.
final todaysShopProvider = Provider<List<DecorItem>>((ref) {
  final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
  return ShopRotation.forDay(
    catalog,
    GameDay.fromInstant(ref.watch(gameClockProvider).now()),
  );
}, dependencies: [decorCatalogProvider, gameClockProvider]);
