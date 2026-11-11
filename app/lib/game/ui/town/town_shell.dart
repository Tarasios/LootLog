/// The Adventure home: the living town fills the window, with the HUD
/// floating over it and, on a wide window, the quest board docked on the
/// right ([TownHomeLayout]). In text tier it is the guild-hall text screens
/// instead (asset ladder tier 3).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart' show Month;
import '../../../features/menu/manage_screen.dart';
import '../../../features/rewards/trophy_hall_screen.dart';
import '../../../features/settings/play_mode.dart';
import '../../../features/settings/play_mode_switch.dart';
import '../../../ui/format.dart';
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_layout.dart' show TownCell, TownLayout;
import '../../domain/town/town_scatter.dart';
import '../../domain/town/town_tags.dart';
import '../../domain/town/town_view.dart';
import '../../scenes/town/town_game.dart' show TownGame;
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
import '../kit/kit.dart' show HudChip;
import 'town_decorate_panel.dart';
import 'town_home_layout.dart';
import 'town_hud.dart';
import 'town_inbox_sheet.dart';
import 'town_ledger_provider.dart';
import 'town_loop_wiring.dart';
import 'town_menu_dialog.dart';
import 'town_place_openers.dart';
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

class _TownShellState extends ConsumerState<TownShell> with TownShellEvents<TownShell>, TownLoopWiring<TownShell> {
  /// "Decorate town" mode: taps place the picked item instead of opening
  /// buildings.
  bool _decorating = false;
  DecorItem? _picked;

  /// The forest around the town, grown once per household seed.
  TownScatter? _scatter;
  int? _scatterSeed;

  /// The same trees and bushes on every device of the household.
  TownScatter _scatterFor(Iterable<String> adultIds) {
    final seed = townScatterSeed(adultIds);
    if (_scatterSeed != seed || _scatter == null) {
      _scatterSeed = seed;
      _scatter = scatterTown(TownLayout.standard, seed: seed);
    }
    return _scatter!;
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
    final scatter = _scatterFor(ledgerView.adults.map((adult) => adult.memberId));
    final me = game.person(ledgerView.meId ?? '');

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
            [
              for (final adult in ledgerView.adults)
                TownAdult(memberId: adult.memberId, name: adult.name, inAdventure: adult.inAdventure),
            ],
            now,
            dungeonOpen: dungeonOpen,
            goalPictures: goalPictureShas,
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
              if (tag.anchor is! StatueAnchor) tag,
          ];
          final loop = townLoopParts(
            tickRef,
            game: game,
            meId: ledgerView.meId ?? '',
            now: now,
            registry: registryLoad.value ?? AssetRegistry.bundled,
          );
          final scene = registryLoad.isLoading && !registryLoad.hasValue
              // The scene reads its art once, so wait for the registry.
              ? const ColoredBox(color: TownGame.forestColour)
              // A new household seed grows a new forest: rebuild the scene.
              : KeyedSubtree(
                  key: ValueKey(_scatterSeed),
                  child: TownSceneView(
                    key: const ValueKey('town-scene'),
                    view: townView,
                    registry: registryLoad.value ?? AssetRegistry.bundled,
                    onTarget: _openTarget,
                    ambientLife: widget.ambientLife,
                    townsfolk: townsfolk,
                    catalog: catalog,
                    pictures: goalPictures,
                    onCellTap: _decorating ? (cell) => unawaited(_placeInTown(cell)) : null,
                    logPulse: logPulse,
                    scatter: scatter,
                    tags: _decorating ? const [] : tags,
                    loop: loop.scene,
                    visitorTag: _decorating ? null : loop.visitorTag,
                    onVisitorTap: _decorating ? null : loop.onVisitorTap,
                  ),
                );
          return Scaffold(
            backgroundColor: TownGame.forestColour,
            body: TownHomeLayout(
              scene: scene,
              onOpenGoals: _openGoals,
              onOpenLedger: onOpenLedger,
              buildHud: (onQuests) => TownHud(
                figures: TownHudFigures(
                  dateLabel: '${monthAbbreviation(today.month)} · day ${today.day}',
                  streak: liveStreak(me.streak, today, tokens: me.freezeTokens),
                  freezeTokens: me.freezeTokens,
                  gems: me.gems,
                  inboxCount: me.unopenedChests.length + me.unclaimedRewards.length,
                  goldPouch: ledger.goldPouch,
                  warChest: ledger.warChest,
                ),
                onQuests: onQuests,
                spiritBar: loop.spiritBar,
                logHint: loop.logHint,
                noSpendCheckIn: NoSpendCheckIn(
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
                  builder: (context, action) =>
                      // Never wider than a narrow phone's corner (it ellipsizes).
                      HudChip(
                        icon: action.icon,
                        value: action.label,
                        onTap: action.onPressed,
                        maxWidth: MediaQuery.sizeOf(context).width - 24,
                      ),
                ),
                onLogPurchase: _logPurchase,
                onShop: _openShop,
                onInbox: () => showTownInbox(context, onOpenLedger: onOpenLedger, links: links),
                onLedger: onOpenLedger,
                onMenu: _openMenu,
                decoratePanel: _decorating
                    ? TownDecoratePanel(
                        personId: ledgerView.meId ?? '',
                        picked: _picked,
                        onPick: (item) => setState(() => _picked = item),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }

  void _openTarget(TownTarget target) {
    final openers = widget.openers;
    switch (target) {
      case PlotTarget(:final plotIndex):
        unawaited(
          showBuildingSheet(
            context,
            plotIndex: plotIndex,
            onOpenLedger: widget.onOpenLedger,
            links: widget.links,
          ),
        );
      case HouseTarget(:final personId):
        final openRoom = openers.openRoom;
        if (openRoom != null) {
          openRoom(context, personId);
        } else {
          unawaited(
            showPlaceComingSheet(context, title: 'Home', body: 'Rooms you can decorate are on their way.'),
          );
        }
      case GateTarget():
        final openDungeon = openers.openDungeon;
        if (openDungeon != null) {
          openDungeon(context);
        } else {
          unawaited(
            showPlaceComingSheet(
              context,
              title: 'The dungeon gate',
              body: 'Each month the gate opens for dividing your leftovers.',
            ),
          );
        }
    }
  }

  /// Quick entry: one tap from the town (the ledger when no link is wired).
  void _logPurchase() {
    final openEntry = widget.links.logPurchase;
    if (openEntry != null) {
      openEntry(context);
    } else {
      widget.onOpenLedger();
    }
  }

  /// The ledger's Goals pane (the ledger when no link is wired).
  void _openGoals() {
    final openGoalsPane = widget.links.openGoals;
    if (openGoalsPane != null) {
      openGoalsPane(context);
    } else {
      widget.onOpenLedger();
    }
  }

  void _openShop() {
    final openShop = widget.openers.openShop;
    if (openShop != null) {
      openShop(context);
    } else {
      unawaited(
        showPlaceComingSheet(
          context,
          title: 'Shop',
          body: 'A new set of decorations arrives every day — opening soon.',
        ),
      );
    }
  }

  void _openMenu() => unawaited(
    showTownMenu(
      context,
      TownMenuActions(
        decorating: _decorating,
        openSettings: () => unawaited(ManageScreen.open(context)),
        switchToStandard: () =>
            unawaited(confirmAndSwitchPlayMode(context, ref, PlayMode.standard, returnHome: true)),
        toggleTextMode: () => ref.read(adventureTierProvider.notifier).toggle(),
        toggleDecorating: _toggleDecorating,
        openTrophies: () => unawaited(TrophyHallScreen.open(context)),
      ),
    ),
  );
}
