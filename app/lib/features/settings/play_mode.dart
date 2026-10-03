/// The per-person play mode — the pure model.
///
/// **Adventure** (the default) is the game: the guild hall, the dungeon skin,
/// and everything that hangs off them. **Standard** is the plain budgeting
/// app. Each adult picks their own; a Standard adult's budgeting still counts
/// for the household, and they can switch to Adventure any time.
///
/// The choice follows the PERSON, not the device: it is stored as a
/// `CosmeticSet` event keyed by member id, so it syncs to every device that
/// adult has paired. Cosmetic events are firewalled (the money reducer ignores
/// them), and switching only ever appends a new setting — nothing is deleted,
/// so switching back to Adventure restores everything.
///
/// This lives outside `lib/game/`: deciding whether to enter the game must not
/// load any game objects. Pure Dart; the Riverpod and file wiring is in
/// `play_mode_providers.dart`.
library;

import '../../domain/event.dart';

/// Which experience a person has chosen.
enum PlayMode { standard, adventure }

/// For Adventure users, the screen the app opens on.
enum AdventureHome { hall, ledger }

/// Where launch lands.
enum HomeDestination { ledger, hall }

/// The cosmetic-setting key holding [memberId]'s play mode.
String playModeKey(String memberId) => 'play.mode.$memberId';

/// The cosmetic-setting key holding [memberId]'s Adventure home screen.
String adventureHomeKey(String memberId) => 'play.home.$memberId';

/// One person's resolved play preferences.
class PlayPrefs {
  const PlayPrefs({required this.mode, required this.home});

  /// Adventure, opening on the Hall.
  static const defaults =
      PlayPrefs(mode: PlayMode.adventure, home: AdventureHome.hall);

  final PlayMode mode;
  final AdventureHome home;

  @override
  bool operator ==(Object other) =>
      other is PlayPrefs && other.mode == mode && other.home == home;

  @override
  int get hashCode => Object.hash(mode, home);
}

/// Resolves [memberId]'s preferences from the event log: the latest valid
/// setting per key by (occurredAt, eventId), so devices agree regardless of
/// the order events synced in. Unrecognised values are skipped. With no mode
/// recorded, [fallbackMode] applies (a device's legacy skin choice, else the
/// Adventure default).
PlayPrefs resolvePlayPrefs(
  Iterable<Event> log,
  String memberId, {
  PlayMode fallbackMode = PlayMode.adventure,
}) {
  final modeKey = playModeKey(memberId);
  final homeKey = adventureHomeKey(memberId);
  final settings = [
    for (final e in log)
      if (e is CosmeticSet && (e.key == modeKey || e.key == homeKey)) e,
  ]..sort((a, b) {
      final byTime = a.occurredAt.compareTo(b.occurredAt);
      return byTime != 0 ? byTime : a.eventId.compareTo(b.eventId);
    });

  var mode = fallbackMode;
  var home = PlayPrefs.defaults.home;
  for (final e in settings) {
    if (e.key == modeKey) {
      mode = playModeFromName(e.value) ?? mode;
    } else {
      home = _byName(AdventureHome.values, e.value) ?? home;
    }
  }
  return PlayPrefs(mode: mode, home: home);
}

/// Parses a stored play-mode value; null when unrecognised.
PlayMode? playModeFromName(Object? name) => _byName(PlayMode.values, name);

T? _byName<T extends Enum>(List<T> values, Object? name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Where launch lands for [prefs]: only Adventure with the Hall home opens the
/// hall; everything else opens the ledger.
HomeDestination homeDestination(PlayPrefs prefs) =>
    prefs.mode == PlayMode.adventure && prefs.home == AdventureHome.hall
        ? HomeDestination.hall
        : HomeDestination.ledger;
