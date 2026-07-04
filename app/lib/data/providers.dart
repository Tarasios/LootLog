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

/// The device-local first-run setup, or null until it has been completed.
final localSetupProvider = StreamProvider<LocalSetup?>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.localSetupDao.watch();
});

/// Whether first-run setup has been completed on this device.
final isSetUpProvider = Provider<bool>((ref) {
  return ref.watch(localSetupProvider).value != null;
});
