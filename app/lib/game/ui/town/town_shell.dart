/// The Adventure home: the town scene under a top bar and above a bottom
/// bar. In text tier it is the guild-hall text screens instead (asset
/// ladder tier 3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/play_mode_switch.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../data/game_providers.dart';
import '../../domain/commands/decor_commands.dart' show starterAcquisitionId;
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_layout.dart' show TownCell;
import '../../domain/town/town_view.dart';
import '../../scenes/town/town_scene_view.dart';
import '../../skin_prefs.dart';
import '../building_sheet.dart';
import '../decor/goal_pictures.dart';
import '../decor/room_screen.dart';
import '../decor/shop_screen.dart';
import '../dungeon/dungeon_providers.dart';
import '../dungeon/dungeon_screen.dart';
import '../game_home.dart';
import '../habit_actions.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart' show HallHomeData;
import '../hall_ledger_view.dart';
import '../hall_status.dart';
import '../hall_voice.dart';
import '../logged_voice.dart';
import 'log_celebration.dart';
import 'town_bottom_bar.dart';
import 'town_decorate_panel.dart';
import 'town_inbox_sheet.dart';
import 'town_place_openers.dart';
import 'town_top_bar.dart';
import 'town_townsfolk.dart';

/// The town with every place wired up. Later tasks add their opener here.
Widget buildTownShell(
  BuildContext context, {
  required VoidCallback onOpenLedger,
  required HallLinks links,
}) => TownShell(
  onOpenLedger: onOpenLedger,
  links: links,
  openers: const TownPlaceOpeners(
    openShop: ShopScreen.open,
    openRoom: RoomScreen.open,
    openDungeon: DungeonScreen.open,
  ),
);

class TownShell extends ConsumerStatefulWidget {
  const TownShell({
    super.key,
    required this.onOpenLedger,
    this.links = const HallLinks(),
    this.openers = const TownPlaceOpeners(),
    @visibleForTesting this.ambientLife = true,
  });

  /// Opens the budgeting ledger.
  final VoidCallback onOpenLedger;

  /// Direct links into ledger screens (quick entry, the ritual's steps).
  final HallLinks links;

  /// What the houses, the gate and the Shop button open.
  final TownPlaceOpeners openers;

  /// Villagers strolling the paths. Off in tests and goldens.
  final bool ambientLife;

  @override
  ConsumerState<TownShell> createState() => _TownShellState();
}

class _TownShellState extends ConsumerState<TownShell> {
  /// Set once the starter claim has been scheduled, so it runs at most once
  /// per visit (the claim is idempotent anyway).
  bool _starterClaimScheduled = false;

  /// "Decorate town" mode: taps place the picked item instead of opening
  /// buildings.
  bool _decorating = false;
  DecorItem? _picked;

  /// The latest log the town celebrates, and a counter telling pulses apart.
  LogPulse? _logPulse;
  int _pulseSequence = 0;

  /// Celebrates a log by this device's adult: gems flying to their house (a
  /// sparkle when the log brought none) in the pixel tier, a short line in
  /// the text tier. Display only.
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
    () => _logPulse = LogPulse(personId: personId, gems: gems, sequence: ++_pulseSequence),
  );

  /// Whether the town's route is on top, as of the last build. The build
  /// depends on the route, so a covering route's pop rebuilds it.
  bool _townIsCurrent = true;

  /// A log celebrated while the town was covered, waiting to play.
  ({String personId, int gems})? _heldLog;

  /// Notes whether the town is on top and, once it is again, plays a held
  /// celebration after this frame.
  void _trackRoute() {
    _townIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    final held = _heldLog;
    if (!_townIsCurrent || held == null) return;
    _heldLog = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _playLog(held.personId, held.gems);
    });
  }

  void _listenForLogs() {
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

  Future<void> _placeInTown(TownCell cell) async {
    final picked = _picked;
    if (picked == null) return;
    await runHallCommand(
      context,
      ref,
      (service) => service.placeItem(
        itemId: picked.id,
        space: DecorSpace.town,
        column: cell.column,
        row: cell.row,
      ),
    );
    if (mounted) setState(() => _picked = null);
  }

  void _toggleDecorating() => setState(() {
    _decorating = !_decorating;
    _picked = null;
  });

  /// Gives a player the starter furniture they have not yet received, once the
  /// catalogue and their game state have loaded. Quiet: never blocks the
  /// scene, and a refusal (already claimed) shows nothing.
  void _claimStarterSetWhenReady(GameState game, String? meId) {
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

  @override
  Widget build(BuildContext context) {
    _trackRoute();
    _listenForLogs();
    final onOpenLedger = widget.onOpenLedger;
    final links = widget.links;
    final openers = widget.openers;
    final textTier = ref.watch(adventureTierProvider) == AdventureTier.text;
    if (textTier) return GameHome(onOpenLedger: onOpenLedger, links: links);

    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final goalPictureShas = ref.watch(goalPictureShasProvider);
    final goalPictures = ref.watch(goalPictureImagesProvider).unwrapPrevious().value ?? const {};
    final game = ref.watch(gameStateProvider).value ?? GameState.initial();
    final ledgerView = ref.watch(hallLedgerViewProvider);
    _claimStarterSetWhenReady(game, ledgerView.meId);
    final townsfolk = ref.watch(townsfolkProvider);
    final registryLoad = ref.watch(gameAssetRegistryProvider);
    final clock = ref.watch(gameClockProvider);
    final battleWaiting = ref.watch(monthEndBattleProvider) != null;
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;

    void openTarget(TownTarget target) => switch (target) {
      PlotTarget(:final plotIndex) => showBuildingSheet(
        context,
        plotIndex: plotIndex,
        onOpenLedger: onOpenLedger,
        links: links,
      ),
      HouseTarget(:final personId) =>
        openers.openRoom != null
            ? openers.openRoom!(context, personId)
            : showPlaceComingSheet(
                context,
                title: 'Home',
                body: 'Rooms you can decorate are on their way.',
              ),
      GateTarget() =>
        openers.openDungeon != null
            ? openers.openDungeon!(context)
            : showPlaceComingSheet(
                context,
                title: 'The dungeon gate',
                body: 'Each month the gate opens for dividing your leftovers.',
              ),
    };

    void openInbox() =>
        showTownInbox(context, onOpenLedger: onOpenLedger, links: links);

    void logPurchase() {
      final openEntry = links.logPurchase;
      if (openEntry != null) {
        openEntry(context);
      } else {
        onOpenLedger();
      }
    }

    void openShop() => openers.openShop != null
        ? openers.openShop!(context)
        : showPlaceComingSheet(
            context,
            title: 'Shop',
            body: 'A new set of decorations arrives every day — opening soon.',
          );

    final me = game.person(ledgerView.meId ?? '');
    return AdventureSpriteScope(
      child: HallTicker(
        builder: (context) {
          final now = clock.now();
          // The gate opens while leftovers wait to be divided, and also for
          // a finished month whose spoils chest has not come home yet (the
          // chest never depends on there being leftovers).
          final dungeonOpen =
              battleWaiting ||
              pendingRitualMonths(
                me,
                now,
                firstBudgetMonth: ledgerView.firstBudgetMonth,
              ).isNotEmpty;
          final townView = TownView.from(
            game,
            [
              for (final adult in ledgerView.adults)
                TownAdult(
                  memberId: adult.memberId,
                  name: adult.name,
                  inAdventure: adult.inAdventure,
                ),
            ],
            now,
            dungeonOpen: dungeonOpen,
            goalPictures: goalPictureShas,
          );
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: registryLoad.isLoading && !registryLoad.hasValue
                      // The scene reads its art once, so wait for the registry.
                      ? const ColoredBox(color: Color(0xFF30346D))
                      : TownSceneView(
                          key: const ValueKey('town-scene'),
                          view: townView,
                          registry: registryLoad.value ?? AssetRegistry.bundled,
                          onTarget: openTarget,
                          ambientLife: widget.ambientLife,
                          townsfolk: townsfolk,
                          catalog: catalog,
                          pictures: goalPictures,
                          onCellTap: _decorating ? (cell) => unawaited(_placeInTown(cell)) : null,
                          logPulse: _logPulse,
                        ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: TownTopBar(
                    me: me,
                    hall: game.hall,
                    streak: liveStreak(
                      me.streak,
                      GameDay.fromInstant(now),
                      tokens: me.freezeTokens,
                    ),
                    actions: [
                      PopupMenuButton<String>(
                        key: const ValueKey('town-menu'),
                        tooltip: 'Town menu',
                        icon: const Icon(Icons.park),
                        onSelected: (_) => _toggleDecorating(),
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'decorate',
                            child: Text(
                              _decorating ? 'Done decorating' : 'Decorate town',
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Text mode',
                        icon: const Icon(Icons.notes),
                        color: Colors.white,
                        onPressed: () =>
                            ref.read(adventureTierProvider.notifier).toggle(),
                      ),
                      const PlayModeMenuButton(),
                    ],
                  ),
                ),
                if (!_decorating)
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: NoSpendCheckIn(
                      key: const ValueKey('town-no-spend'),
                      explainWhenUnavailable: true,
                      data: HallHomeData(
                        game: game,
                        view: ledgerView,
                        voice: voice,
                        now: now,
                        onOpenLedger: onOpenLedger,
                        links: links,
                      ),
                      builder: (context, action) => ActionChip(
                        avatar: Icon(action.icon, size: 18),
                        label: Text(action.label),
                        onPressed: action.onPressed,
                      ),
                    ),
                  ),
                if (_decorating)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: TownDecoratePanel(
                      personId: ledgerView.meId ?? '',
                      picked: _picked,
                      onPick: (item) => setState(() => _picked = item),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: TownBottomBar(
              onLogPurchase: logPurchase,
              onShop: openShop,
              onInbox: openInbox,
              onBudget: onOpenLedger,
              inboxCount: me.unopenedChests.length + me.unclaimedRewards.length,
            ),
          );
        },
      ),
    );
  }
}
