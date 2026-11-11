/// The Adventure home: one district of the living town fills the window
/// (the district strip moves between them, [TownDistrictWiring]), with the
/// HUD floating over it and, on a wide window, the quest board docked on the
/// right ([TownHomeLayout]). In text tier it is the guild-hall text screens
/// instead (asset ladder tier 3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart' show Month;
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/districts.dart' show kOutpostDistrictId;
import '../../domain/town/town_growth_lines.dart';
import '../../domain/town/town_tags.dart';
import '../../domain/town/town_view.dart';
import '../../scenes/town/town_game.dart' show TownGame;
import '../../scenes/town/town_scene_view.dart';
import '../../skin_prefs.dart';
import '../decor/goal_pictures.dart';
import '../decor/room_screen.dart';
import '../decor/shop_screen.dart';
import '../dungeon/dungeon_providers.dart';
import '../dungeon/dungeon_screen.dart';
import '../game_home.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import '../hall_status.dart';
import '../hall_voice.dart';
import 'neighbour_providers.dart';
import 'town_book_screen.dart';
import 'town_decorate_panel.dart';
import 'town_decorate_wiring.dart';
import 'town_district_wiring.dart';
import 'town_growth_providers.dart';
import 'town_home_layout.dart';
import 'hud_insets.dart';
import 'town_home_hud.dart';
import 'town_inbox_sheet.dart';
import 'town_ledger_provider.dart';
import 'town_loop_wiring.dart';
import 'town_neighbour_wiring.dart';
import 'town_place_openers.dart';
import 'town_shell_actions.dart';
import 'town_shell_events.dart';
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

  /// Direct links into ledger screens (quick entry, the Goals pane, the
  /// ritual's steps).
  final HallLinks links;

  /// What the houses, the gate and the Shop button open.
  final TownPlaceOpeners openers;

  /// Villagers strolling the paths. Off in tests and goldens.
  final bool ambientLife;

  @override
  ConsumerState<TownShell> createState() => _TownShellState();
}

class _TownShellState extends ConsumerState<TownShell>
    with
        TownShellEvents<TownShell>,
        TownLoopWiring<TownShell>,
        TownDistrictWiring<TownShell>,
        TownNeighbourWiring<TownShell>,
        TownShellActions,
        TownDecorateWiring {
  /// How much of a phone's scene the HUD covers (the HUDs measure it).
  final HudInsets _hudInsets = HudInsets();

  @override
  void dispose() {
    _hudInsets.dispose();
    super.dispose();
  }

  /// A visit is strictly read-only: decorating ends when one starts.
  @override
  void onVisitStarted() => endDecorating();

  @override
  Widget build(BuildContext context) {
    trackRoute();
    listenForLogs();
    final onOpenLedger = widget.onOpenLedger;
    final links = widget.links;
    final textTier = ref.watch(adventureTierProvider) == AdventureTier.text;
    if (textTier) return GameHome(onOpenLedger: onOpenLedger, links: links);

    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final goalPictureShas = ref.watch(goalPictureShasProvider);
    final goalPictures = ref.watch(goalPictureImagesProvider).unwrapPrevious().value ?? const {};
    final game = ref.watch(gameStateProvider).value ?? GameState.initial();
    final ledgerView = ref.watch(hallLedgerViewProvider);
    claimStarterSetWhenReady(game, ledgerView.meId);
    final townsfolk = ref.watch(townsfolkProvider);
    final registryLoad = ref.watch(gameAssetRegistryProvider);
    final clock = ref.watch(gameClockProvider);
    final battle = ref.watch(monthEndBattleProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final tagLines = ref.watch(townTagLinesProvider).value ?? TownTagLines.defaults;
    final growthLines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final scatter = scatterFor(openLayout, ledgerView.adults.map((adult) => adult.memberId));
    final me = game.person(ledgerView.meId ?? '');
    final myTown = game.townOf(ledgerView.meId ?? '');
    final neighbours = myNeighbours(game, ledgerView);
    // A visit shows the neighbour's town read-only (`TownNeighbourWiring`).
    final visiting = visitingAmong(neighbours);
    final shownTown = visiting == null ? myTown : game.townOf(visiting.memberId);
    final inOutpost = openDistrictId == kOutpostDistrictId && visiting == null;

    return AdventureSpriteScope(
      child: HallTicker(
        // A Consumer under the ticker, so what depends on the date (the bill
        // countdowns, the quest board's month) is read again on every tick,
        // not only on ledger changes.
        builder: (context) => Consumer(builder: (context, tickRef, _) {
          final now = clock.now();
          final today = GameDay.fromInstant(now);
          final ledger = tickRef.watch(townLedgerProvider(Month.fromInstant(now)));
          // The gate opens while leftovers wait to be divided, and also for
          // a finished month whose spoils chest has not come home yet (the
          // chest never depends on there being leftovers).
          final dungeonOpen =
              battle != null ||
              pendingRitualMonths(me, now, firstBudgetMonth: ledgerView.firstBudgetMonth).isNotEmpty;
          final townView = TownView.from(
            game,
            visiting?.memberId ?? ledgerView.meId ?? '',
            townAdults(ledgerView),
            now,
            districtId: openDistrictId,
            dungeonOpen: dungeonOpen && visiting == null,
            goalPictures: goalPictureShas,
            neighbours: visiting == null ? neighbours : const [],
          );
          // Goals in progress live on the quest board, not as signs in the
          // square (the square keeps the statues of goals already won).
          final tags = [
            for (final tag in townTags(
              view: townView,
              board: ledger.board,
              leftoversToDivide: battle?.weapons.length ?? 0,
              upcomingBills: tickRef.watch(townBillsProvider(today)),
              unopenedChests: me.unopenedChests.length,
              lines: tagLines,
            ))
              if (tag.anchor is! StatueAnchor && inOutpost) tag,
          ];
          final loop = townLoopParts(
            tickRef,
            game: game,
            meId: ledgerView.meId ?? '',
            now: now,
            registry: registryLoad.value ?? AssetRegistry.bundled,
            visiting: visiting != null,
          );
          final decorating = decoratingTown && visiting == null;
          final scene = registryLoad.isLoading && !registryLoad.hasValue
              // The scene reads its art once, so wait for the registry.
              ? const ColoredBox(color: TownGame.forestColour)
              // A new household seed grows a new forest: rebuild the scene.
              : slidingDistrict(KeyedSubtree(
                  key: ValueKey('$scatterSeed:${visiting?.memberId}'),
                  child: ValueListenableBuilder<EdgeInsets>(
                    valueListenable: _hudInsets,
                    builder: (context, hudInsets, _) => TownSceneView(
                    key: const ValueKey('town-scene'),
                    hudInsets: hudInsets,
                    view: townView,
                    registry: registryLoad.value ?? AssetRegistry.bundled,
                    onTarget: (target) => visiting != null
                        ? openVisitTarget(target, townView, visiting)
                        : target is SignpostTarget
                        ? openSignpost(neighbours)
                        : openHomeTarget(target),
                    ambientLife: widget.ambientLife,
                    townsfolk: townsfolk,
                    catalog: catalog,
                    pictures: goalPictures,
                    onCellTap: decorating ? (cell) => unawaited(placeInTown(cell)) : null,
                    logPulse: logPulse,
                    scatter: scatter,
                    tags: decorating ? const [] : tags,
                    // The visitor and the festival bunting are in the outpost.
                    loop: inOutpost ? loop.scene : TownLoopScene.none,
                    visitorTag: decorating || !inOutpost ? null : loop.visitorTag,
                    onVisitorTap: decorating || !inOutpost ? null : loop.onVisitorTap,
                    onSwipePastEdge: decorating ? null : (direction) => openNeighbour(shownTown, direction),
                  ),
                  ),
                ));
          return Scaffold(
            backgroundColor: TownGame.forestColour,
            body: TownHomeLayout(
              scene: scene,
              onOpenGoals: openGoals,
              onOpenLedger: onOpenLedger,
              buildHud: (onQuests) => visiting != null
                  ? neighbourHud(
                      visiting: visiting,
                      game: game,
                      meId: ledgerView.meId ?? '',
                      now: now,
                      onLogPurchase: logPurchase,
                      districtStrip: districtStrip(shownTown, growthLines, readOnly: true),
                      insets: _hudInsets,
                    )
                  : TownHomeHud(
                      game: game,
                      ledgerView: ledgerView,
                      voice: voice,
                      now: now,
                      ledger: ledger,
                      loop: loop,
                      links: links,
                      onOpenLedger: onOpenLedger,
                      onLogPurchase: logPurchase,
                      onShop: openShop,
                      onInbox: () => showTownInbox(context, onOpenLedger: onOpenLedger, links: links),
                      onMenu: openTownMenu,
                      onDate: () => unawaited(TownBookScreen.open(context)),
                      onQuests: onQuests,
                      districtStrip: decorating ? null : districtStrip(myTown, growthLines),
                      decoratePanel: decorating
                          ? TownDecoratePanel(
                              personId: ledgerView.meId ?? '',
                              picked: pickedDecoration,
                              onPick: pickDecoration,
                            )
                          : null,
                      insets: _hudInsets,
                    ),
            ),
          );
        }),
      ),
    );
  }
}
