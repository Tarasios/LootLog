/// The month-end dungeon below the town gate. Each category's leftover is a
/// weapon; each turn aims it at a goal boss, an OVERBUDGET, savings or the
/// category itself, previewed by the shared move module. Nothing is written
/// until "Return to town": then one result goes through the shared spoils
/// path, followed by the cosmetic spoils chest. Leaving early writes nothing,
/// so the ledger's own grace-period defaults still apply.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../features/household_context.dart';
import '../../../features/report/report_screen.dart';
import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../../ui/format.dart';
import '../../assets/asset_key.dart';
import '../../assets/asset_registry.dart';
import '../../assets/game_asset_scope.dart';
import '../../battle/month_end_battle.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../../scenes/dungeon/dungeon_game.dart';
import '../../scenes/dungeon/dungeon_scene_view.dart';
import '../../scenes/pack_atlas.dart';
import '../../skin_prefs.dart';
import '../../text_mode/text_battle.dart';
import 'battle_turn_sheet.dart';
import 'dungeon_commit.dart';
import 'dungeon_providers.dart';
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

  Future<Map<String, ui.Image>> _decodePictures(MonthEndBattle battle) async {
    final pictures = <String, ui.Image>{};
    for (final boss in battle.bosses) {
      final sha = boss.pictureSha256;
      if (sha == null) continue;
      try {
        final codec = await ui.instantiateImageCodec(await ref.read(blobStoreProvider).read(sha));
        pictures[boss.questId] = (await codec.getNextFrame()).image;
      } on Object {
        // A missing or unreadable picture just leaves the boss on its own.
        continue;
      }
    }
    return pictures;
  }

  Future<void> _buildGame(MonthEndBattle battle) async {
    final pictures = await _decodePictures(battle);
    if (!mounted) {
      for (final picture in pictures.values) {
        picture.dispose();
      }
      return;
    }
    _pictures.addAll(pictures);
    AssetRegistry registry;
    try {
      registry = await ref.read(gameAssetRegistryProvider.future);
    } on Object {
      registry = AssetRegistry.bundled;
    }
    if (!mounted) return;
    final game = ref.read(gameStateProvider).value ?? GameState.initial();
    final meId = ref.read(meUserIdProvider) ?? '';
    final catalog = ref.read(decorCatalogProvider).value ?? DecorCatalog.empty;
    final outfitId = game.decor.outfitOf(meId);
    setState(() => _game = DungeonGame(
          atlas: PackAtlas(registry, Images(prefix: 'assets/game/')),
          bosses: battle.bosses,
          debts: battle.debts,
          heroKey: (outfitId == null ? null : catalog.itemFor(outfitId)?.assetKey) ?? const AssetKey('hero', 'body'),
          pictures: pictures,
          moneyLabel: money,
        ));
  }

  String _seed(String part) => '${_battle?.ritual.month.toKey()}:$part';

  /// The log line for one confirmed move, in game voice, with the real split.
  String _moveLine(DungeonVoice voice, BattleWeapon weapon, SpoilsChoice choice, SpoilsMovePreview preview) {
    final seed = _seed(weapon.sliceId);
    final amount = money(preview.landsCents);
    final lines = <String>[
      switch (choice.move) {
        SpoilsMove.goal => voice.line('hitGoal',
            seed: seed, fill: {'amount': amount, 'target': _bossName(choice.questId) ?? weapon.name}),
        SpoilsMove.debt => voice.line('hitDebt',
            seed: seed, fill: {'amount': amount, 'target': _debtName(choice.overbudgetSliceId) ?? weapon.name}),
        SpoilsMove.bank => voice.line('bank', seed: seed, fill: {'amount': amount}),
        SpoilsMove.carry => voice.line('carry', seed: seed, fill: {'amount': amount, 'name': weapon.name}),
      },
      if (preview.taxCents > 0) voice.line('taxFlies', seed: seed, fill: {'amount': money(preview.taxCents)}),
      if (choice.move == SpoilsMove.goal && preview.completesTarget)
        voice.line('bossFalls', seed: seed, fill: {'target': _bossName(choice.questId) ?? weapon.name}),
    ];
    return lines.join(' ');
  }

  String? _bossName(String? questId) => _bosses.where((boss) => boss.questId == questId).firstOrNull?.name;

  String? _debtName(String? sliceId) => _debts.where((debt) => debt.sliceId == sliceId).firstOrNull?.name;

  Future<void> _takeTurn(BattleWeapon weapon) async {
    final choice = await showBattleTurnSheet(context, weapon: weapon, bosses: _bosses, debts: _debts, isAdventure: true);
    if (choice == null || !mounted) return;
    final preview = previewSpoilsChoice(weapon.leftover, choice);
    final voice = ref.read(dungeonVoiceProvider).value ?? DungeonVoice.empty;
    final targetId = switch (choice.move) {
      SpoilsMove.goal => choice.questId,
      SpoilsMove.debt => choice.overbudgetSliceId,
      _ => null,
    };
    final line = _moveLine(voice, weapon, choice, preview);
    _choices[weapon.sliceId] = choice;
    setState(() {
      _bosses = [for (final boss in _bosses) boss.questId == targetId ? boss.afterLanding(preview.landsCents) : boss];
      _debts = [for (final debt in _debts) debt.sliceId == targetId ? debt.afterLanding(preview.landsCents) : debt];
      _log.add(line);
      _turn++;
      if (_turn >= _battle!.weapons.length) _stage = _DungeonStage.victory;
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
    final MonthEndGameOutcome outcome;
    try {
      outcome = await finishMonthEndGame(container, battle.ritual.month);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _chestPending = true;
      });
      return;
    }
    if (!mounted) return;
    await showMonthEndCelebration(context, container, outcome, seed: _seed('victory'));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final battle = _battle;
    final voice = ref.watch(dungeonVoiceProvider).value ?? DungeonVoice.empty;
    if (ref.watch(adventureTierProvider) == AdventureTier.text && battle != null) {
      // Text tier: the turn-based text battle, fed by the same ritual and
      // written through the same path.
      return textTierBattle(context, battle.ritual);
    }
    if (battle != null) _requestGame(battle);
    return AdventureSpriteScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('The dungeon')),
        body: switch ((battle, _stage)) {
          (null, _) => _GateClosed(line: voice.line('gateClosed')),
          (final MonthEndBattle open, _DungeonStage.upkeep) => UpkeepStep(
              tallies: open.upkeep,
              intro: voice.line('upkeep', seed: _seed('upkeep')),
              onDone: (actuals) => setState(() {
                _actuals = actuals;
                _stage = _DungeonStage.battle;
              }),
            ),
          (final MonthEndBattle open, final _DungeonStage stage) => Column(children: [
              Expanded(
                flex: 3,
                child: _game == null
                    ? const ColoredBox(color: Color(0xFF140C1C), child: SizedBox.expand())
                    : DungeonSceneView(key: const ValueKey('dungeon-scene'), game: _game!),
              ),
              if (stage == _DungeonStage.victory)
                Expanded(
                  flex: 2,
                  child: _Victory(
                    battle: open,
                    bosses: _bosses,
                    debts: _debts,
                    headline: voice.line('victory', seed: _seed('victory')),
                    pendingNote: _chestPending ? voice.line('chestPending') : null,
                    saving: _saving,
                    onReturn: _returnToTown,
                  ),
                )
              else
                _TurnPanel(
                  log: _log,
                  intro: open.weapons.isEmpty
                      ? voice.line('noLeftovers', seed: _seed('none'))
                      : _turn == 0 && _log.isEmpty
                          ? voice.line('gateOpen', seed: _seed('open'))
                          : null,
                  weapon: open.weapons.isEmpty ? null : open.weapons[_turn],
                  weaponLine: open.weapons.isEmpty
                      ? null
                      : voice.line('weaponReady', seed: _seed(open.weapons[_turn].sliceId), fill: {
                          'name': open.weapons[_turn].name,
                          'amount': money(open.weapons[_turn].valueCents),
                        }),
                  onTakeTurn: _takeTurn,
                  headBackLabel: voice.line('headBack'),
                  onHeadBack: () => setState(() => _stage = _DungeonStage.victory),
                ),
            ]),
        },
      ),
    );
  }
}

/// The text tier's battle: the turn-based text view for [ritual]. Its
/// result is written through the shared spoils path, then the spoils chest,
/// the celebration and the month's report follow.
Widget textTierBattle(BuildContext context, SpoilsRitual ritual) => TextBattleView(
      ritual: ritual,
      onDismiss: () => Navigator.of(context).maybePop(),
      onConfirm: (result) => unawaited(_finishTextBattle(context, ritual, result)),
    );

/// The text battle pops on confirm (so it can't be confirmed twice), writes
/// the ledger once, then brings the chest home. A failed chest never undoes
/// or repeats the ledger write: a dialog says the leftovers are saved and
/// offers to retry the chest alone.
Future<void> _finishTextBattle(BuildContext context, SpoilsRitual ritual, SpoilsResult result) async {
  final navigator = Navigator.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  navigator.pop();
  try {
    await writeMonthEndLedger(container, ritual, result);
  } on Object {
    if (navigator.mounted) showMonthEndSaveFailed(navigator.context, container);
    return;
  }
  MonthEndGameOutcome? outcome;
  while (outcome == null && navigator.mounted) {
    try {
      outcome = await finishMonthEndGame(container, ritual.month);
    } on Object {
      if (!navigator.mounted || !await askRetryChest(navigator.context, container)) break;
    }
  }
  if (!navigator.mounted) return;
  if (outcome != null) {
    await showMonthEndCelebration(navigator.context, container, outcome, seed: '${ritual.month.toKey()}:victory');
  }
  if (navigator.mounted) await ReportScreen.open(navigator.context, initialMonth: ritual.month);
}

class _GateClosed extends StatelessWidget {
  const _GateClosed({required this.line});

  final String line;

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(24), child: Text(line));
}

/// Under the scene while weapons remain: the last move's line, the next
/// weapon, and the button that aims it.
class _TurnPanel extends StatelessWidget {
  const _TurnPanel({
    required this.log,
    required this.intro,
    required this.weapon,
    required this.weaponLine,
    required this.onTakeTurn,
    required this.headBackLabel,
    required this.onHeadBack,
  });

  final String headBackLabel;
  final List<String> log;
  final String? intro;
  final BattleWeapon? weapon;
  final String? weaponLine;
  final void Function(BattleWeapon weapon) onTakeTurn;
  final VoidCallback onHeadBack;

  @override
  Widget build(BuildContext context) {
    final next = weapon;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (log.isNotEmpty) Text(log.last, key: const ValueKey('dungeon-log')),
          if (intro case final String line) Text(line),
          if (weaponLine case final String line) ...[
            const SizedBox(height: 8),
            Text(line, style: Theme.of(context).textTheme.titleSmall),
          ],
          const SizedBox(height: 12),
          if (next == null)
            FilledButton(onPressed: onHeadBack, child: Text(headBackLabel))
          else
            FilledButton(
              key: const ValueKey('next-weapon'),
              onPressed: () => onTakeTurn(next),
              child: Text('${next.name}: ${money(next.valueCents)}'),
            ),
        ]),
      ),
    );
  }
}

class _Victory extends StatelessWidget {
  const _Victory({
    required this.battle,
    required this.bosses,
    required this.debts,
    required this.headline,
    required this.pendingNote,
    required this.saving,
    required this.onReturn,
  });

  /// Shown when the leftovers are saved but the chest has not arrived.
  final String? pendingNote;

  final MonthEndBattle battle;
  final List<GoalBoss> bosses;
  final List<DebtMonster> debts;
  final String headline;
  final bool saving;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(headline, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final boss in bosses)
          ListTile(
            title: Text(boss.name),
            subtitle: LinearProgressIndicator(value: boss.revealFraction),
            trailing: Text(boss.remainingCents == 0 ? 'Done!' : '${money(boss.remainingCents)} to go'),
          ),
        for (final debt in debts)
          ListTile(
            title: Text('OVERBUDGET on ${debt.name}'),
            trailing: Text(debt.outstandingCents == 0 ? 'Cleared!' : '${money(debt.outstandingCents)} left to clear'),
          ),
        if (battle.groupFlows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Shared budgets march in on their own', style: Theme.of(context).textTheme.titleSmall),
          for (final flow in battle.groupFlows)
            ListTile(
              dense: true,
              title: Text(flow.name),
              trailing: Text('${money(flow.leftoverCents)} to the war chest'),
            ),
        ],
        const SizedBox(height: 12),
        if (pendingNote case final String note) ...[
          Text(note, key: const ValueKey('chest-pending')),
          const SizedBox(height: 8),
        ],
        FilledButton(onPressed: saving ? null : onReturn, child: const Text('Return to town')),
      ]);
}
