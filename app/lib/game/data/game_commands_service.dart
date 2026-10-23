/// The guild hall's write side for the UI: runs one pure command
/// (`GameCommands`) against the current game state and appends what it
/// returns.
///
/// Every method reads the whole game log, projects it, runs the command with
/// this device's clock and stamp, appends the events if accepted, and returns
/// the [GameCommandResult] — so the caller can show the outcome (the chest's
/// contents, the expedition report, the boss fight) straight from
/// `result.events`, or map `result.rejection` to friendly copy. Calls from
/// one service run one at a time, so a double tap can't spend gems twice.
///
/// Nothing here touches the ledger except to read it (the boss fight's
/// logged-day count). Pure Dart; the Riverpod wiring is in
/// `game_providers.dart`.
library;

import '../../domain/event.dart';
import '../../domain/time.dart';
import '../domain/clock.dart';
import '../domain/commands/decor_commands.dart';
import '../domain/commands/game_commands.dart';
import '../domain/decor/catalog.dart';
import '../domain/decor/decor_values.dart';
import '../domain/game_event_stamp.dart';
import '../domain/game_event_store.dart';
import '../domain/game_projection.dart';
import '../domain/game_values.dart';
import '../domain/ledger_inputs.dart';

export '../domain/commands/game_commands.dart'
    show GameCommandResult, GameRejection;

/// The one line every game command on this device waits in, so each command
/// sees the events of the one before. It outlives any single
/// [GameCommandsService]: the service is rebuilt when, say, the decoration
/// catalogue finishes loading, and commands queued on the old service and
/// the new one must still never race.
class GameCommandQueue {
  Future<void> _tail = Future.value();

  /// Runs [body] after every earlier call has finished (or failed).
  Future<T> serialized<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (Object _) {});
    return result;
  }
}

class GameCommandsService {
  GameCommandsService({
    required this.store,
    required this.actorId,
    required this.stamp,
    this.clock = const SystemClock(),
    this.ledger,
    this.catalog = DecorCatalog.empty,
    GameCommandQueue? queue,
  }) : queue = queue ?? GameCommandQueue();

  /// Where game events are read from and appended to.
  final GameEventStore store;

  /// The person acting on this device (their member id is also their hero's
  /// id).
  final String actorId;

  final Clock clock;

  /// This device, and how new event ids are made.
  final GameEventStamp stamp;

  /// Reads the ledger, for the few money-free facts a command needs (the
  /// boss fight's logged-day count). Null treats those counts as zero.
  final Future<List<Event>> Function()? ledger;

  /// The decoration catalogue the decoration commands look items up in.
  final DecorCatalog catalog;

  /// The line [run] and [runDecor] share, so each call sees the previous
  /// call's events (shared with earlier services on this device).
  final GameCommandQueue queue;

  Future<T> _serialized<T>(Future<T> Function() body) => queue.serialized(body);

  /// Runs [command] against the current state and appends its events when
  /// accepted. Serialized: each call sees the previous call's events.
  Future<GameCommandResult> run(
    GameCommandResult Function(GameCommands commands) command,
  ) => _serialized(() async {
    final state = projectGameState(await store.all());
    final result = command(
      GameCommands(
        state: state,
        clock: clock,
        actorId: actorId,
        stamp: stamp,
        catalog: catalog,
      ),
    );
    if (result.accepted && result.events.isNotEmpty) {
      await store.append(result.events);
    }
    return result;
  });

  /// Like [run], for the decoration commands.
  Future<GameCommandResult> runDecor(
    GameCommandResult Function(DecorCommands commands) command,
  ) => _serialized(() async {
    final state = projectGameState(await store.all());
    final result = command(
      DecorCommands(
        state: state,
        clock: clock,
        actorId: actorId,
        stamp: stamp,
        catalog: catalog,
      ),
    );
    if (result.accepted && result.events.isNotEmpty) {
      await store.append(result.events);
    }
    return result;
  });

  // ---- Hall ----------------------------------------------------------------

  /// Unlocks hall plot [plotIndex] for gems.
  Future<GameCommandResult> unlockPlot(int plotIndex) =>
      run((c) => c.unlockPlot(plotIndex));

  /// Builds [type] on an empty plot, or upgrades the [type] standing there.
  Future<GameCommandResult> startBuilding(int plotIndex, BuildingType type) =>
      run((c) => c.startBuilding(plotIndex, type));

  /// Collects a producer's materials into the shared pool.
  Future<GameCommandResult> collectMaterials(int plotIndex) =>
      run((c) => c.collectMaterials(plotIndex));

  // ---- Chests and rewards ----------------------------------------------------

  /// Opens a waiting chest; the [ChestOpened] event holds what it rolled.
  ///
  /// Refused until the decoration catalogue has loaded: the roll is stored in
  /// the event for good, so opening a chest without it would silently lose
  /// the chest's decoration.
  Future<GameCommandResult> openChest(String chestId) {
    if (catalog.items.isEmpty) {
      return Future.value(
        const GameCommandResult.rejected(GameRejection.catalogNotReady),
      );
    }
    return run((c) => c.openChest(chestId));
  }

  /// Claims a waiting reward.
  Future<GameCommandResult> claimReward(String rewardId) =>
      run((c) => c.claimReward(rewardId));

  // ---- Heroes ------------------------------------------------------------------

  /// Upgrades [heroId]'s gear in [slot] by one tier (this device's adult pays).
  Future<GameCommandResult> upgradeGear({
    required String heroId,
    required String slot,
    required String gearType,
  }) =>
      run((c) => c.upgradeGear(heroId: heroId, slot: slot, gearType: gearType));

  /// Sets a cosmetic field on this device's adult's hero.
  Future<GameCommandResult> customizeHero({
    required String field,
    required String value,
  }) => run((c) => c.customizeHero(field: field, value: value));

  // ---- Expeditions ---------------------------------------------------------------

  /// Sends this device's adult's hero to [region].
  Future<GameCommandResult> startExpedition(ExpeditionRegion region) =>
      run((c) => c.startExpedition(region));

  /// Brings the hero home; the [ExpeditionResolved] event holds loot and
  /// report.
  Future<GameCommandResult> resolveExpedition() =>
      run((c) => c.resolveExpedition());

  // ---- Spoils ritual -----------------------------------------------------------------

  /// Marks one ritual step for [month] done.
  ///
  /// Kept for log compatibility: the month-end dungeon replaced the four-step
  /// ritual, so no UI calls this any more.
  Future<GameCommandResult> completeRitualStep(Month month, RitualStep step) =>
      run((c) => c.completeRitualStep(month, step));

  /// Fights [month]'s boss once the ritual is done, with the month's
  /// logged-day count read from the ledger.
  ///
  /// Kept for log compatibility: the seasonal boss is retired, so no UI calls
  /// this any more.
  Future<GameCommandResult> fightBoss(Month month) async {
    final read = ledger;
    final days = read == null
        ? 0
        : loggedDaysInMonth(await read(), actorId, month);
    return run((c) => c.fightBoss(month, loggedDays: days));
  }

  /// Finishes [month]'s month-end dungeon: the spoils chest and the on-time
  /// bonus ([onTimeRitualMonths] is read from the ledger by the caller).
  Future<GameCommandResult> finishMonthRitual(
    Month month, {
    required int onTimeRitualMonths,
  }) => run(
    (commands) => commands.finishMonthRitual(
      month,
      onTimeRitualMonths: onTimeRitualMonths,
    ),
  );

  // ---- Party ---------------------------------------------------------------------------

  /// Joins the household party. (The reward runner already keeps membership
  /// in step with the play mode; this is for an explicit UI action.)
  Future<GameCommandResult> joinParty() => run((c) => c.joinParty());

  /// Leaves the party.
  Future<GameCommandResult> leaveParty() => run((c) => c.leaveParty());

  // ---- Decoration ------------------------------------------------------------------------

  /// Buys [itemId] from today's shop.
  Future<GameCommandResult> buyItem(String itemId) =>
      runDecor((commands) => commands.buyItem(itemId));

  /// Claims the one-time starter furniture set.
  Future<GameCommandResult> claimStarterSet() =>
      runDecor((commands) => commands.claimStarterSet());

  /// Places an owned [itemId] at a cell of [space].
  Future<GameCommandResult> placeItem({
    required String itemId,
    required DecorSpace space,
    required int column,
    required int row,
    int rotation = 0,
    String? placementId,
  }) => runDecor(
    (commands) => commands.placeItem(
      itemId: itemId,
      space: space,
      column: column,
      row: row,
      rotation: rotation,
      placementId: placementId,
    ),
  );

  /// Takes a placed item back into the inventory.
  Future<GameCommandResult> storePlacement(String placementId) =>
      runDecor((commands) => commands.storePlacement(placementId));

  /// Equips an owned outfit piece on this device's adult's hero.
  Future<GameCommandResult> equipItem(String itemId) =>
      runDecor((commands) => commands.equipItem(itemId));
}
