/// Riverpod wiring, writers, and legacy-pref migration for the per-person
/// play mode (see `play_mode.dart` for the model).
library;

// Tiny deliberate file IO; async keeps it off the UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/event.dart';
import '../../domain/ids.dart';
import 'play_mode.dart';

/// Records this device's adult's play mode. [at] defaults to now.
Future<void> setPlayMode(HouseholdActions actions, PlayMode mode,
        {DateTime? at}) =>
    _set(actions, playModeKey(actions.meUserId), mode.name, at);

/// Records this device's adult's Adventure home screen. [at] defaults to now.
Future<void> setAdventureHome(HouseholdActions actions, AdventureHome home,
        {DateTime? at}) =>
    _set(actions, adventureHomeKey(actions.meUserId), home.name, at);

Future<void> _set(
    HouseholdActions actions, String key, String value, DateTime? at) {
  final now = (at ?? DateTime.now()).toUtc();
  return actions.append(CosmeticSet(
    eventId: uuidv7(millisSinceEpoch: now.millisecondsSinceEpoch),
    deviceId: actions.deviceId,
    userId: actions.meUserId,
    occurredAt: now,
    createdAt: now,
    key: key,
    value: value,
  ));
}

/// Reads the retired per-device skin file (`app_skin.txt`) that the play mode
/// replaced: Classic → Standard, Adventure → Adventure, missing or unreadable
/// → null. A device's old choice is the fallback until its adult picks a mode,
/// so an update never flips someone who chose Classic into the game.
Future<PlayMode?> loadLegacySkinMode() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, 'app_skin.txt'));
    if (!await f.exists()) return null;
    return switch ((await f.readAsString()).trim()) {
      'classic' => PlayMode.standard,
      'adventure' => PlayMode.adventure,
      _ => null,
    };
  } on Object {
    return null;
  }
}

/// The legacy device skin, loaded once.
final legacySkinModeProvider =
    FutureProvider<PlayMode?>((ref) => loadLegacySkinMode());

/// This device's adult's play preferences, or null while setup, the event log,
/// or the legacy skin pref are still loading (the launch gate shows a loading
/// screen until then rather than flashing the wrong home).
final playPrefsProvider = Provider<PlayPrefs?>((ref) {
  final setup = ref.watch(localSetupProvider);
  final log = ref.watch(eventLogProvider);
  final legacy = ref.watch(legacySkinModeProvider);
  final me = setup.value?.meUserId;
  if (me == null || !log.hasValue || legacy.isLoading) return null;
  return resolvePlayPrefs(log.requireValue, me,
      fallbackMode: legacy.value ?? PlayPrefs.defaults.mode);
});

/// Whether this device's adult is in Adventure mode. False while loading, so
/// nothing game-side is built before the mode is known.
final isAdventureProvider = Provider<bool>(
    (ref) => ref.watch(playPrefsProvider)?.mode == PlayMode.adventure);
