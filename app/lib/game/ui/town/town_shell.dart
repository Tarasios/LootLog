/// The Adventure home: the town scene under a top bar and above a bottom
/// bar. In text tier it is the guild-hall text screens instead (asset
/// ladder tier 3).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/settings/play_mode_switch.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../data/game_providers.dart';
import '../../domain/commands/decor_commands.dart' show starterAcquisitionId;
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_view.dart';
import '../../scenes/town/town_scene_view.dart';
import '../../skin_prefs.dart';
import '../building_sheet.dart';
import '../decor/room_screen.dart';
import '../decor/shop_screen.dart';
import '../game_home.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import '../hall_status.dart';
import 'town_bottom_bar.dart';
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
    final onOpenLedger = widget.onOpenLedger;
    final links = widget.links;
    final openers = widget.openers;
    final textTier = ref.watch(adventureTierProvider) == AdventureTier.text;
    if (textTier) return GameHome(onOpenLedger: onOpenLedger, links: links);

    ref.watch(decorCatalogProvider);
    final game = ref.watch(gameStateProvider).value ?? GameState.initial();
    final ledgerView = ref.watch(hallLedgerViewProvider);
    _claimStarterSetWhenReady(game, ledgerView.meId);
    final townsfolk = ref.watch(townsfolkProvider);
    final registryLoad = ref.watch(gameAssetRegistryProvider);
    final clock = ref.watch(gameClockProvider);

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
          final townView = TownView.from(game, [
            for (final adult in ledgerView.adults)
              TownAdult(
                memberId: adult.memberId,
                name: adult.name,
                inAdventure: adult.inAdventure,
              ),
          ], now);
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
