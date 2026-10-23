/// Runs the guild hall's reward engine against the stored log and records
/// what it grants. Called after every local ledger write and after every sync
/// merge (pull, hub push, file import).
///
/// The engine is idempotent, so running too often is harmless and a missed run
/// heals on the next one. It only ever appends to the game log, never the
/// ledger — the money reducer cannot see what it writes (the firewall).
library;

import '../domain/event.dart';
import '../domain/reducer.dart';
import '../domain/state.dart';
import '../features/settings/play_mode.dart';
import '../game/domain/clock.dart';
import '../game/domain/game_projection.dart';
import '../game/domain/rewards/reward_engine.dart';
import 'db/database.dart';

/// Whether this household may write ledger event types newer than the 1.0
/// release (the no-spend check-in and the weekly reconcile).
///
/// Releases before the savings economy throw on an unknown ledger event type,
/// so a new type stops an old device's sync. Adopting the savings rules
/// already tells the household to update every device first (and new
/// households adopt at onboarding), so it doubles as the opt-in for these.
/// Game events need no gate: they travel in their own log, which older
/// devices never request.
bool householdAcceptsNewEventTypes(HouseholdState state) =>
    state.savingsRules != null;

/// The household's adults and their play modes, from synced events only.
///
/// A device's legacy skin file is deliberately not consulted: it exists on
/// one device, and every device must agree on who is in Adventure for the
/// rewards to come out the same everywhere. An adult with no recorded mode
/// counts as Adventure, the default.
Party partyOf(HouseholdState state, List<Event> log) {
  final ids = state.adultIds.toList()..sort();
  return Party([
    for (final id in ids)
      PartyAdult(
        id,
        inAdventure: resolvePlayPrefs(log, id).mode == PlayMode.adventure,
      ),
  ]);
}

class GameRewardRunner {
  GameRewardRunner({
    required this.db,
    required this.deviceId,
    this.clock = const SystemClock(),
    this.engine = const RewardEngine(),
  });

  final AppDatabase db;
  final String deviceId;
  final Clock clock;
  final RewardEngine engine;

  Future<int>? _running;
  bool _again = false;

  /// Evaluates and records any newly earned game events. Returns how many were
  /// written. Overlapping calls coalesce into one follow-up run. Never throws:
  /// a reward failure must not break a purchase or a sync.
  Future<int> run() async {
    if (_running != null) {
      _again = true;
      return _running!;
    }
    final run = _runLoop();
    _running = run;
    try {
      return await run;
    } finally {
      _running = null;
    }
  }

  Future<int> _runLoop() async {
    var written = 0;
    do {
      _again = false;
      try {
        written += await _runOnce();
      } on Object {
        // Silent: rewards catch up on the next write or sync.
      }
    } while (_again);
    return written;
  }

  Future<int> _runOnce() async {
    final ledger = await db.eventsDao.allEvents();
    final household = reduce(ledger, asOf: clock.now());
    final out = engine.evaluate(
      ledger,
      projectGameState(await db.gameEventsDao.allGameEvents()),
      clock,
      party: partyOf(household, ledger),
      stamp: GameEventStamp(deviceId: deviceId),
    );
    if (out.isEmpty) return 0;
    await db.gameEventsDao.appendGameEvents(out);
    return out.length;
  }
}
