/// Month close as a turn-based text battle. Each personal category that left
/// loot behind is a felled monster; for each the player chooses one move —
/// carry the loot into next floor, hurl it at a quest boss, or pocket it in the
/// gold pouch. Attacks show the damage and the war-chest tithe split, narrating
/// the cut on a category mismatch. Every number comes from the spoils model
/// (the reducer's math); this screen decides nothing financial, it just frames
/// the choice and hands back a [SpoilsResult] for the shared commit path.
library;

import 'package:flutter/material.dart';

import '../../domain/money.dart';
import '../../domain/value_types.dart';
import '../../features/spoils/spoils_model.dart';
import '../../features/spoils/spoils_move.dart';
import '../../features/spoils/spoils_sheet.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'text_widgets.dart';

/// The move chosen for one felled monster's loot.
enum _Move { smite, carry, attack, pouch }

/// The turn-based month-close battle, rendered in text. Pure: it takes the
/// ritual view-model and hands back a confirmed [SpoilsResult]; the caller
/// appends the events.
class TextBattleView extends StatefulWidget {
  const TextBattleView({
    super.key,
    required this.ritual,
    required this.onConfirm,
    this.onDismiss,
  });

  final SpoilsRitual ritual;
  final ValueChanged<SpoilsResult> onConfirm;
  final VoidCallback? onDismiss;

  @override
  State<TextBattleView> createState() => _TextBattleViewState();
}

class _TextBattleViewState extends State<TextBattleView> {
  final Map<String, int> _actuals = {};
  final Map<String, _Move> _move = {};
  final Map<String, String?> _questChoice = {};
  final Map<String, String?> _overbudgetChoice = {};

  @override
  void initState() {
    super.initState();
    for (final leftover in widget.ritual.sliceLeftovers) {
      // The OVERBUDGET MUST be dealt with: while one looms, smiting it is the
      // pre-selected move; skipping it is a deliberate switch.
      _move[leftover.sliceId] =
          leftover.overbudgetOptions.isNotEmpty ? _Move.smite : _defaultMove(leftover);
      _questChoice[leftover.sliceId] = _defaultQuest(leftover);
      _overbudgetChoice[leftover.sliceId] = leftover.overbudgetOptions.isNotEmpty
          ? leftover.overbudgetOptions.first.sliceId
          : null;
    }
  }

  static _Move _defaultMove(SliceLeftover leftover) => switch (leftover.defaultPolicy) {
        CarryInSlice() => _Move.carry,
        QuestDestination() => _Move.attack,
        Discretionary() => _Move.pouch,
        OverbudgetPayment() => _Move.smite,
      };

  static String? _defaultQuest(SliceLeftover leftover) {
    final policy = leftover.defaultPolicy;
    if (policy is QuestDestination) return policy.questId;
    return leftover.questOptions.isNotEmpty ? leftover.questOptions.first.questId : null;
  }

  OverbudgetOption? _chosenOverbudget(SliceLeftover leftover) {
    final id = _overbudgetChoice[leftover.sliceId];
    for (final option in leftover.overbudgetOptions) {
      if (option.sliceId == id) return option;
    }
    return leftover.overbudgetOptions.isNotEmpty ? leftover.overbudgetOptions.first : null;
  }

  /// The battle's selection for [leftover] as the shared month-end choice.
  SpoilsChoice _choiceFor(SliceLeftover leftover) => SpoilsChoice(
        switch (_move[leftover.sliceId]!) {
          _Move.smite => SpoilsMove.debt,
          _Move.carry => SpoilsMove.carry,
          _Move.attack => SpoilsMove.goal,
          _Move.pouch => SpoilsMove.bank,
        },
        questId: _questChoice[leftover.sliceId],
        overbudgetSliceId: _overbudgetChoice[leftover.sliceId],
      );

  void _confirm() {
    final tallies = <TallyResult>[
      for (final tally in widget.ritual.variableTallies)
        TallyResult(
          expenseId: tally.expenseId,
          actualCents: _actuals[tally.expenseId] ?? tally.estimateCents,
        ),
    ];
    final allocations = <SliceAllocationResult>[
      for (final leftover in widget.ritual.sliceLeftovers)
        SliceAllocationResult(
          sliceId: leftover.sliceId,
          allocations: allocationsForChoice(leftover, _choiceFor(leftover)),
        ),
    ];
    widget.onConfirm(SpoilsResult(tallies: tallies, allocations: allocations));
  }

  @override
  Widget build(BuildContext context) {
    final ritual = widget.ritual;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Month-close battle'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Retreat (resume later)',
          onPressed: widget.onDismiss ?? () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _intro(context),
                if (ritual.variableTallies.isNotEmpty) _quartermaster(context),
                if (ritual.sliceLeftovers.isEmpty)
                  TextPanel(
                    title: 'No loot to divide',
                    icon: Icons.check_circle_outline,
                    child: Text('Every monster fell clean. Nothing to split.',
                        style: monoStyle(context)),
                  )
                else
                  for (var i = 0; i < ritual.sliceLeftovers.length; i++)
                    _turn(context, i + 1, ritual.sliceLeftovers[i]),
                if (ritual.groupFlows.isNotEmpty || ritual.emergencyContribs.isNotEmpty)
                  _autoFlows(context),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _confirm,
                  icon: const Icon(Icons.sports_martial_arts),
                  label: const Text('Strike! — divide the spoils'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _intro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ritual = widget.ritual;
    return TextPanel(
      title: 'Dividing the spoils · '
          '${monthLabel(ritual.month.year, ritual.month.month)}',
      icon: Icons.auto_awesome,
      accent: scheme.tertiary,
      child: Text(
        'The floor is cleared. Defaults apply in ${ritual.daysRemaining} '
        'day${ritual.daysRemaining == 1 ? '' : 's'} if you leave it — but the loot '
        'is yours to divide now.',
        style: monoStyle(context, color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _quartermaster(BuildContext context) {
    return TextPanel(
      title: 'Settle with the quartermaster',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record the true tally for each variable provision.',
              style: monoStyle(context,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          for (final tally in widget.ritual.variableTallies)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(child: Text(tally.name, style: monoStyle(context))),
                  Text(money(_actuals[tally.expenseId] ?? tally.estimateCents),
                      style: monoStyle(context, weight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => _editActual(tally),
                    child: const Text('Tally'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _turn(BuildContext context, int turnNumber, SliceLeftover leftover) {
    final move = _move[leftover.sliceId]!;
    return TextPanel(
      title: 'Turn $turnNumber · ${leftover.name} felled',
      icon: Icons.sports_martial_arts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${money(leftover.leftoverCents)} in loot to divide.',
              style: monoStyle(context, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_Move>(
            segments: [
              if (leftover.overbudgetOptions.isNotEmpty)
                const ButtonSegment(
                  value: _Move.smite,
                  icon: Icon(Icons.gavel_outlined, size: 16),
                  label: Text('OVERBUDGET'),
                ),
              const ButtonSegment(
                value: _Move.carry,
                icon: Icon(Icons.arrow_forward, size: 16),
                label: Text('Carry'),
              ),
              ButtonSegment(
                value: _Move.attack,
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Attack'),
                enabled: leftover.questOptions.isNotEmpty,
              ),
              const ButtonSegment(
                value: _Move.pouch,
                icon: Icon(Icons.savings_outlined, size: 16),
                label: Text('Pouch'),
              ),
            ],
            selected: {move},
            onSelectionChanged: (selection) =>
                setState(() => _move[leftover.sliceId] = selection.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          _outcome(context, leftover, move),
        ],
      ),
    );
  }

  Widget _outcome(BuildContext context, SliceLeftover leftover, _Move move) {
    final scheme = Theme.of(context).colorScheme;
    switch (move) {
      case _Move.smite:
        final option = _chosenOverbudget(leftover);
        if (option == null) {
          return Text('No OVERBUDGET looms.',
              style: monoStyle(context, color: scheme.onSurfaceVariant));
        }
        final preview = previewOverbudgetPayment(
          leftover.leftoverCents,
          leftover.poolTithePct,
          outstandingCents: option.outstandingCents,
          sliceMainCategoryId: leftover.mainCategoryId,
          targetMainCategoryId: option.mainCategoryId,
        );
        final felled = preview.payCents >= option.outstandingCents;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leftover.overbudgetOptions.length > 1)
              DropdownButton<String>(
                value: option.sliceId,
                isDense: true,
                onChanged: (value) =>
                    setState(() => _overbudgetChoice[leftover.sliceId] = value),
                items: [
                  for (final debtOption in leftover.overbudgetOptions)
                    DropdownMenuItem(
                        value: debtOption.sliceId,
                        child: Text(debtOption.mainCategoryId != null &&
                                debtOption.mainCategoryId == leftover.mainCategoryId
                            ? '${debtOption.name} (same category, no tithe)'
                            : debtOption.name)),
                ],
              ),
            Text(
              '→ ${money(preview.payCents)} smites the OVERBUDGET on ${option.name}.',
              style: monoStyle(context, weight: FontWeight.w700,
                  color: scheme.error),
            ),
            if (preview.matched)
              Text('   Matching category — full value, no tithe.',
                  style: monoStyle(context, color: scheme.tertiary))
            else if (preview.titheCents > 0)
              Text(
                '   The war chest takes its cut first: '
                '${money(preview.titheCents)} (${leftover.poolTithePct}%).',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            Text(
              felled
                  ? '   THE OVERBUDGET FALLS. ${option.name} unlocks.'
                  : '   It staggers — ${money(option.outstandingCents - preview.payCents)} '
                      'HP remains. ${option.name} stays locked.',
              style: monoStyle(context,
                  color: felled ? scheme.tertiary : scheme.onSurfaceVariant),
            ),
            if (preview.toVaultCents > 0)
              Text(
                '   It takes no more than it needs: ${money(preview.toVaultCents)} '
                'to your pouch'
                '${preview.excessTitheCents > 0 ? ' after a ${money(preview.excessTitheCents)} tithe' : ''}.',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
          ],
        );
      case _Move.carry:
        return Text(
          '→ ${money(leftover.leftoverCents)} carried whole into next floor\'s '
          '${leftover.name}. Its limit rises.',
          style: monoStyle(context, color: scheme.primary),
        );
      case _Move.pouch:
        final split =
            previewDiscretionary(leftover.leftoverCents, leftover.poolTithePct);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('→ ${money(split.vaultCents)} to your gold pouch.',
                style: monoStyle(context, color: scheme.tertiary)),
            if (split.titheCents > 0)
              Text(
                '   ${money(split.titheCents)} tithed to the war chest '
                '(${leftover.poolTithePct}%).',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
          ],
        );
      case _Move.attack:
        if (leftover.questOptions.isEmpty) {
          return Text('No quest boss to strike.',
              style: monoStyle(context, color: scheme.onSurfaceVariant));
        }
        final questId = _questChoice[leftover.sliceId] ?? leftover.questOptions.first.questId;
        final quest = leftover.questOptions.firstWhere((option) => option.questId == questId,
            orElse: () => leftover.questOptions.first);
        final split = previewQuestAttack(
          leftover.leftoverCents,
          leftover.poolTithePct,
          sliceMainCategoryId: leftover.mainCategoryId,
          questMainCategoryId: quest.mainCategoryId,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: questId,
              isDense: true,
              onChanged: (value) =>
                  setState(() => _questChoice[leftover.sliceId] = value),
              items: [
                for (final option in leftover.questOptions)
                  DropdownMenuItem(value: option.questId, child: Text(option.name)),
              ],
            ),
            Text(
              '→ ${money(split.damageCents)} damage to ${quest.name}.',
              style: monoStyle(context, weight: FontWeight.w700,
                  color: scheme.secondary),
            ),
            if (split.matched)
              Text('   Matching category — full damage, no tithe.',
                  style: monoStyle(context, color: scheme.tertiary))
            else if (split.titheCents > 0)
              Text(
                '   The war chest takes its cut: ${money(split.titheCents)} '
                'flies off (${leftover.poolTithePct}%).',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
          ],
        );
    }
  }

  Widget _autoFlows(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Coins that arc on their own',
      icon: Icons.route_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final flow in widget.ritual.groupFlows)
            Text('· ${flow.name}: ${money(flow.leftoverCents)} → the war chest',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
          for (final contribution in widget.ritual.emergencyContribs)
            Text('· ${contribution.fundName}: ${money(contribution.amountCents)} → a reserve cache',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _editActual(VariableTally tally) async {
    final controller = TextEditingController(
      text: Money(_actuals[tally.expenseId] ?? tally.estimateCents).format(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tally.name),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              const InputDecoration(prefixText: '\$', labelText: 'Actual'),
          onSubmitted: (_) => _submitActual(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _submitActual(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _actuals[tally.expenseId] = result);
    }
  }

  void _submitActual(BuildContext context, String text) {
    try {
      final cents = Money.parse(text).cents;
      Navigator.pop(context, cents < 0 ? 0 : cents);
    } on FormatException {
      Navigator.pop(context);
    }
  }
}
