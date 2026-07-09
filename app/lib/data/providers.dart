/// Riverpod wiring for the data layer.
///
/// The database and blob store are provided as overridable dependencies so the
/// app can inject file-backed instances at startup and tests can inject
/// in-memory ones. Everything derived flows from a single reactive stream: the
/// event log is watched, replayed through the pure reducer, and surfaced as
/// [householdStateProvider]. The domain never computes balances itself.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/event.dart';
import '../domain/reducer.dart';
import '../domain/state.dart';
import '../game/rewards/homestead.dart';
import '../game/rewards/rewards.dart';
import 'blobs/blob_store.dart';
import 'db/database.dart';
import 'setup/local_setup.dart';

/// The open [AppDatabase]. Must be overridden (in `main` with a file-backed
/// database, in tests with an in-memory one).
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError(
    'appDatabaseProvider must be overridden with an open AppDatabase',
  );
});

/// The [BlobStore]. Must be overridden with a documents-directory-backed store.
final blobStoreProvider = Provider<BlobStore>((ref) {
  throw UnimplementedError(
    'blobStoreProvider must be overridden with a BlobStore',
  );
});

/// The full event log, re-emitted on every table change.
final eventLogProvider = StreamProvider<List<Event>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.eventsDao.watchAllEvents();
});

/// The derived household read-model: the event log replayed through the reducer
/// whenever the log changes. This is the single source of truth the UI, game
/// skin, sync, and exports all read from.
final householdStateProvider = StreamProvider<HouseholdState>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.eventsDao.watchAllEvents().map(reduce);
});

/// The read-time cosmetic rewards snapshot (streaks, trophies, reached tiers).
/// Pure display-side derivation — it never moves a cent.
final rewardsSnapshotProvider = Provider<RewardsSnapshot?>((ref) {
  final state = ref.watch(householdStateProvider).value;
  final log = ref.watch(eventLogProvider).value;
  if (state == null || log == null) return null;
  return computeRewards(state, log, asOf: DateTime.now().toUtc());
});

/// The cosmetic rewards already recorded as [GameRewardGranted] events — the
/// synced, persistent record the trophy hall renders.
final grantedRewardsProvider = Provider<List<GameRewardGranted>>((ref) {
  final log = ref.watch(eventLogProvider).value ?? const [];
  return [
    for (final e in log)
      if (e is GameRewardGranted) e,
  ]..sort((a, b) => b.grantedAt.compareTo(a.grantedAt));
});

/// The renameable Homestead flavour name, from the latest `homestead.flavor`
/// cosmetic setting, or the default.
final homesteadFlavorProvider = Provider<String>((ref) {
  final log = ref.watch(eventLogProvider).value ?? const [];
  String flavor = HomesteadConfig.defaults().flavorName;
  for (final e in log) {
    if (e is CosmeticSet && e.key == 'homestead.flavor' && e.value is String) {
      flavor = e.value! as String;
    }
  }
  return flavor;
});

/// The read-time Homestead meta-progression view: the war chest visualized as a
/// homestead built up in stages. Pure visualization of the real pool balance.
final homesteadViewProvider = Provider<HomesteadView?>((ref) {
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return null;
  final defaults = HomesteadConfig.defaults();
  final config = HomesteadConfig(
    flavorName: ref.watch(homesteadFlavorProvider),
    stages: defaults.stages,
  );
  return buildHomestead(state, config: config);
});

/// The device-local first-run setup, or null until it has been completed.
final localSetupProvider = StreamProvider<LocalSetup?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.localSetupDao.watch();
});

/// Whether first-run setup has been completed on this device.
final isSetUpProvider = Provider<bool>((ref) {
  return ref.watch(localSetupProvider).value != null;
});
