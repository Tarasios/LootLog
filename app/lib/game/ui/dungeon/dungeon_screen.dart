/// The month-end dungeon below the town gate. Each category's leftover is a
/// weapon; each turn aims it at a goal boss, an OVERBUDGET, savings or the
/// category itself, previewed by the shared move module. Nothing is written
/// until "Return to town": then one result goes through the shared spoils
/// path, followed by the cosmetic spoils chest. Leaving early writes nothing,
/// so the ledger's own grace-period defaults still apply.
///
/// The chest never depends on leftovers or on how they were divided: when the
/// ledger has nothing left to divide for a finished month (all spent, past
/// the grace period, or already divided in the ledger) and its chest has not
/// come home, the dungeon is a short victory that grants only the chest.
///
/// This file holds the battle's state and its one ledger write; the framed
/// layout ([DungeonBattleLayout]), the turn ([BattleTurnPanel]) and the
/// panels around it draw what it holds.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../../ui/format.dart';
import '../../assets/game_asset_scope.dart';
import '../../battle/month_end_battle.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../scenes/dungeon/dungeon_game.dart';
import '../../scenes/dungeon/dungeon_scene_view.dart';
import '../../skin_prefs.dart';
import '../hall_ledger_view.dart';
import '../hall_status.dart';
import '../kit/kit.dart';
import 'battle_turn_panel.dart';
import 'dungeon_battle_layout.dart';
import 'dungeon_commit.dart';
import 'dungeon_move_line.dart';
import 'dungeon_panels.dart';
import 'dungeon_party.dart';
import 'dungeon_providers.dart';
import 'dungeon_scene_loader.dart';
import 'dungeon_text_tier.dart';
import 'dungeon_tokens.dart';
import 'dungeon_voice.dart';
import 'upkeep_step.dart';

enum _DungeonStage { upkeep, battle, victory }

class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DungeonScreen()));

  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen> {
  /// Read once on entry: the battle being fought does not change under the
  /// player while they fight it.
  MonthEndBattle? _battle;
  late _DungeonStage _stage;
  Map<String, int> _actuals = const {};
  final Map<String, SpoilsChoice> _choices = {};
  int _turn = 0;
  List<GoalBoss> _bosses = const [];
  List<DebtMonster> _debts = const [];
  final List<String> _log = [];
  DungeonGame? _game;
  bool _gameRequested = false;
  final Map<String, ui.Image> _pictures = {};
  bool _saving = false;

  /// The ledger write for this battle has succeeded: it is never made again,
  /// only the chest is retried.
  bool _ledgerWritten = false;

  /// The ledger is written but the chest has not arrived yet.
  bool _chestPending = false;

  /// With no battle: the finished month whose spoils chest this visit brings
  /// home. Fixed once chosen, so granting the chest does not change it.
  Month? _returnMonth;

  @override
  void initState() {
    super.initState();
    final battle = ref.read(monthEndBattleProvider);
    _battle = battle;
    _bosses = battle?.bosses ?? const [];
    _debts = battle?.debts ?? const [];
    _stage = (battle?.upkeep.isNotEmpty ?? false) ? _DungeonStage.upkeep : _DungeonStage.battle;
  }

  @override
  void dispose() {
    for (final picture in _pictures.values) {
      picture.dispose();
    }
    super.dispose();
  }

  /// Builds the pixel scene the first time it is needed (never in text tier).
  void _requestGame(MonthEndBattle battle) {
    if (_gameRequested) return;
    _gameRequested = true;
    unawaited(_buildGame(battle));
  }

  Future<void> _buildGame(MonthEndBattle battle) async {
    final load = await loadDungeonScene(ProviderScope.containerOf(context, listen: false), battle);
    if (!mounted) {
      for (final picture in load.pictures.values) {
        picture.dispose();
      }
      return;
    }
    _pictures.addAll(load.pictures);
    setState(() => _game = load.game);
  }

  String _seed(String part) => '${_battle?.ritual.month.toKey()}:$part';

  /// Swings [weapon] at [choice]. A strike for a weapon that is no longer on
  /// the card (a second tap before the card changed) is ignored, so each
  /// weapon is swung exactly once, in turn order.
  Future<void> _takeTurn(BattleWeapon weapon, SpoilsChoice choice) async {
    final battle = _battle!;
    if (_stage != _DungeonStage.battle || _turn >= battle.weapons.length || battle.weapons[_turn] != weapon) {
      return;
    }
    // Against where earlier weapons left the goals and debts, as the ledger
    // will apply the allocations in turn order.
    final preview = previewSpoilsChoice(leftoverAgainst(weapon.leftover, bosses: _bosses, debts: _debts), choice);
    final voice = ref.read(dungeonVoiceProvider).value ?? DungeonVoice.empty;
    final targetId = switch (choice.move) {
      SpoilsMove.goal => choice.questId,
      SpoilsMove.debt => choice.overbudgetSliceId,
      _ => null,
    };
    final line = dungeonMoveLine(
      voice,
      seed: _seed(weapon.sliceId),
      weapon: weapon,
      choice: choice,
      preview: preview,
      bosses: _bosses,
      debts: _debts,
    );
    _choices[weapon.sliceId] = choice;
    setState(() {
      _bosses = [for (final boss in _bosses) boss.questId == targetId ? boss.afterLanding(preview.landsCents) : boss];
      _debts = [for (final debt in _debts) debt.sliceId == targetId ? debt.afterLanding(preview.landsCents) : debt];
      _log.add(line);
      _turn++;
      if (_turn >= battle.weapons.length) _stage = _DungeonStage.victory;
    });
    final game = _game;
    if (game != null) {
      await game.showHit(targetId: targetId ?? '', landsCents: preview.landsCents, taxCents: preview.taxCents);
      game.updateTargets(_bosses, _debts);
    }
  }

  /// Writes the ledger once, then brings the chest home. A failed ledger
  /// write can be retried as a whole; once it has succeeded, a failed chest
  /// keeps the screen open with an honest note, and the next tap retries the
  /// chest alone. Leaving then is fine too: the leftovers are divided.
  Future<void> _returnToTown() async {
    if (_saving) return;
    final battle = _battle!;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _saving = true);
    if (!_ledgerWritten) {
      try {
        await writeMonthEndLedger(
          container,
          battle.ritual,
          battle.resultFor(choices: _choices, actualsByExpenseId: _actuals),
        );
        _ledgerWritten = true;
      } on Object {
        if (!mounted) return;
        setState(() => _saving = false);
        showMonthEndSaveFailed(context, container);
        return;
      }
    }
    await _bringChestHome(container, battle.ritual.month, seed: _seed('victory'));
  }

  /// Grants [month]'s spoils chest and celebrates, then leaves. A failed
  /// chest keeps the screen open with a note; the next tap tries again.
  Future<void> _bringChestHome(ProviderContainer container, Month month, {required String seed}) async {
    final MonthEndGameOutcome outcome;
    try {
      outcome = await finishMonthEndGame(container, month);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _chestPending = true;
      });
      return;
    }
    if (!mounted) return;
    await showMonthEndCelebration(context, container, outcome, seed: seed);
    if (mounted) Navigator.of(context).pop();
  }

  /// The oldest finished month still waiting for its spoils chest.
  Month? _watchReturnMonth() {
    final game = ref.watch(gameStateProvider).value;
    final view = ref.watch(hallLedgerViewProvider);
    final meId = view.meId;
    if (game == null || meId == null) return null;
    return pendingRitualMonths(
      game.person(meId),
      ref.watch(gameClockProvider).now(),
      firstBudgetMonth: view.firstBudgetMonth,
    ).firstOrNull;
  }

  /// Nothing left to divide in the ledger: brings [month]'s chest home and
  /// writes nothing to the ledger.
  Future<void> _returnWithSpoils(Month month) async {
    if (_saving) return;
    final container = ProviderScope.containerOf(context, listen: false);
    setState(() => _saving = true);
    await _bringChestHome(container, month, seed: '${month.toKey()}:victory');
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    final voice = ref.watch(dungeonVoiceProvider).value ?? DungeonVoice.empty;
    final returnMonth = battle == null ? (_returnMonth ??= _watchReturnMonth()) : null;
    if (ref.watch(adventureTierProvider) == AdventureTier.text && battle != null) {
      // Text tier: the turn-based text battle, fed by the same ritual and
      // written through the same path.
      return textTierBattle(context, battle.ritual);
    }
    if (battle != null) _requestGame(battle);
    return AdventureSpriteScope(
      child: Scaffold(
        backgroundColor: kDungeonStone,
        body: Column(
          children: [
            const GameScreenHeader(title: 'The dungeon'),
            Expanded(
              child: switch ((battle, _stage)) {
          (null, _) when returnMonth != null => SpoilsReturnPanel(
              headline: voice.line('nothingToDivide',
                  seed: '${returnMonth.toKey()}:return',
                  fill: {'month': monthLabel(returnMonth.year, returnMonth.month)}),
              pendingNote: _chestPending ? voice.line('returnPending') : null,
              saving: _saving,
              onReturn: () => unawaited(_returnWithSpoils(returnMonth)),
            ),
          (null, _) => DungeonGateClosed(line: voice.line('gateClosed')),
          (final MonthEndBattle open, _DungeonStage.upkeep) => UpkeepStep(
              tallies: open.upkeep,
              intro: voice.line('upkeep', seed: _seed('upkeep')),
              onDone: (actuals) => setState(() {
                _actuals = actuals;
                _stage = _DungeonStage.battle;
              }),
            ),
          (final MonthEndBattle open, final _DungeonStage stage) => DungeonBattleLayout(
              party: _partyFrames(open),
              floorRows: DungeonGame.rowsFor(open.bosses.length + open.debts.length),
              floorTitle: monthLabel(open.ritual.month.year, open.ritual.month.month),
              floor: _game == null
                  ? const ColoredBox(color: Color(0xFF140C1C), child: SizedBox.expand())
                  : DungeonSceneView(key: const ValueKey('dungeon-scene'), game: _game!),
              turn: stage == _DungeonStage.victory ? _victory(open, voice) : _turnArea(open, voice),
              logLines: [
                open.weapons.isEmpty
                    ? voice.line('noLeftovers', seed: _seed('none'))
                    : voice.line('gateOpen', seed: _seed('open')),
                ..._log,
              ],
            ),
              },
            ),
          ],
        ),
      ),
    );
  }

  /// The party around the floor: every adult, this one swinging the weapons.
  List<DungeonPartyFrame> _partyFrames(MonthEndBattle battle) {
    final view = ref.watch(hallLedgerViewProvider);
    final game = ref.watch(gameStateProvider).value;
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    return dungeonPartyFrames(
      adults: [
        for (final adult in view.adults) (memberId: adult.memberId, name: adult.name, inAdventure: adult.inAdventure),
      ],
      meId: view.meId,
      weaponsSwung: _turn,
      weaponCount: battle.weapons.length,
      outfitOf: (memberId) => game == null ? null : outfitKeyOf(game, catalog, memberId),
    );
  }

  /// The weapon on the card and its targets, or — with nothing left over —
  /// the way back up.
  Widget _turnArea(MonthEndBattle battle, DungeonVoice voice) {
    if (battle.weapons.isEmpty) {
      return WoodButton(
        label: voice.line('headBack'),
        expand: true,
        onPressed: () => setState(() => _stage = _DungeonStage.victory),
      );
    }
    final weapon = battle.weapons[_turn];
    return BattleTurnPanel(
      key: ValueKey('turn-${weapon.sliceId}'),
      weapon: weapon,
      bosses: _bosses,
      debts: _debts,
      isAdventure: true,
      compact: MediaQuery.sizeOf(context).width < AdventureTokens.wideBreakpoint,
      flavourLine: voice.line('weaponReady',
          seed: _seed(weapon.sliceId), fill: {'name': weapon.name, 'amount': money(weapon.valueCents)}),
      onStrike: (choice) => unawaited(_takeTurn(weapon, choice)),
    );
  }

  Widget _victory(MonthEndBattle battle, DungeonVoice voice) => DungeonVictoryPanel(
        battle: battle,
        bosses: _bosses,
        debts: _debts,
        headline: voice.line('victory', seed: _seed('victory')),
        pendingNote: _chestPending ? voice.line('chestPending') : null,
        saving: _saving,
        onReturn: _returnToTown,
      );
}
