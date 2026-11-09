/// What the town does on its own as events land: celebrates this adult's
/// logs (gems flying home, or a short line in the text tier), holding a
/// celebration while another screen covers the town, and hands a new player
/// their starter furniture once. Display and cosmetic rewards only.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_catalog.dart';
import '../../data/game_providers.dart';
import '../../domain/commands/decor_commands.dart' show starterAcquisitionId;
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../scenes/town/town_scene_view.dart' show LogPulse;
import '../../skin_prefs.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import '../logged_voice.dart';
import 'log_celebration.dart';

/// Log celebrations and the starter set, for the town shell's state.
mixin TownShellEvents<Shell extends ConsumerStatefulWidget> on ConsumerState<Shell> {
  /// Set once the starter claim has been scheduled, so it runs at most once
  /// per visit (the claim is idempotent anyway).
  bool _starterClaimScheduled = false;

  /// The latest log the town celebrates, and a counter telling pulses apart.
  LogPulse? logPulse;
  int _pulseSequence = 0;

  /// Whether the town's route is on top, as of the last build. The build
  /// depends on the route, so a covering route's pop rebuilds it.
  bool _townIsCurrent = true;

  /// A log celebrated while the town was covered, waiting to play.
  ({String personId, int gems})? _heldLog;

  /// Celebrates a log by this device's adult: gems flying to their house (a
  /// sparkle when the log brought none) in the pixel tier, a short line in
  /// the text tier.
  void _celebrateLog({required int gems, required bool purchaseLogged}) {
    final meId = ref.read(hallLedgerViewProvider).meId;
    if (meId == null || meId.isEmpty || !mounted) return;
    if (ref.read(adventureTierProvider) == AdventureTier.text) {
      if (!purchaseLogged) return;
      final voice = ref.read(loggedVoiceProvider).value ?? LoggedVoice.empty;
      final today = GameDay.fromInstant(ref.read(gameClockProvider).now());
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(voice.line(seed: '${today.toKey()}:${_pulseSequence++}'))),
      );
      return;
    }
    if (!_townIsCurrent) {
      // A screen (the entry screen, say) covers the town and the scene keeps
      // ticking underneath: hold the celebration until the town is back.
      _heldLog = (personId: meId, gems: (_heldLog?.gems ?? 0) + gems);
      return;
    }
    _playLog(meId, gems);
  }

  void _playLog(String personId, int gems) => setState(
    () => logPulse = LogPulse(personId: personId, gems: gems, sequence: ++_pulseSequence),
  );

  /// Notes whether the town is on top and, once it is again, plays a held
  /// celebration after this frame. Call at the top of every build.
  void trackRoute() {
    _townIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final held = _heldLog;
    if (!_townIsCurrent || held == null) return;
    _heldLog = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playLog(held.personId, held.gems);
    });
  }

  /// Listens for new logging gems and logged purchases. Call in every build.
  void listenForLogs() {
    // The first game state is the baseline: only rewards granted after it
    // are celebrated.
    ref.listen(gameStateProvider, (previous, next) {
      final before = previous?.value;
      final after = next.value;
      final meId = ref.read(hallLedgerViewProvider).meId;
      if (before == null || after == null || meId == null) return;
      final gems = newLoggingGems(before, after, meId);
      if (gems > 0) _celebrateLog(gems: gems, purchaseLogged: false);
    });
    ref.listen(loggedPurchaseCountProvider, (previous, next) {
      if (previous == null || next == null || next <= previous) return;
      _celebrateLog(gems: 0, purchaseLogged: true);
    });
    // Load the lines before the first log needs one.
    ref.watch(loggedVoiceProvider);
  }

  /// Gives a player the starter furniture they have not yet received, once the
  /// catalogue and their game state have loaded. Quiet: never blocks the
  /// scene, and a refusal (already claimed) shows nothing.
  void claimStarterSetWhenReady(GameState game, String? meId) {
    if (_starterClaimScheduled || meId == null || meId.isEmpty) return;
    final catalog = ref.read(decorCatalogProvider).value;
    if (catalog == null || catalog.starterSet.isEmpty) return;
    if (!ref.read(gameStateProvider).hasValue) return;
    final starterPending = catalog.starterSet.any(
      (item) => !game.decor.seenAcquisitionIds.contains(
        starterAcquisitionId(meId, item.id),
      ),
    );
    if (!starterPending) return;
    _starterClaimScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _claimStarterSet());
  }

  Future<void> _claimStarterSet() async {
    final service = ref.read(gameCommandsServiceProvider);
    if (service == null) {
      _starterClaimScheduled = false;
      return;
    }
    try {
      final result = await service.claimStarterSet();
      if (!result.accepted || result.events.isEmpty || !mounted) return;
    } on Object {
      // Silent: a later rebuild tries again.
      _starterClaimScheduled = false;
      return;
    }
    await showHallCelebration(
      context,
      sprite: GameAssetKeys.chest(ChestType.wood),
      title: 'Welcome home',
      lines: const ['Your first furniture is waiting inside your house.'],
    );
  }
}
