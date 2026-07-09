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
import '../../features/spoils/spoils_sheet.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'text_widgets.dart';

/// The move chosen for one felled monster's loot.
enum _Move { carry, attack, pouch }

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

  @override
  void initState() {
    super.initState();
    for (final s in widget.ritual.sliceLeftovers) {
      _move[s.sliceId] = _defaultMove(s);
      _questChoice[s.sliceId] = _defaultQuest(s);
    }
  }

  static _Move _defaultMove(SliceLeftover s) => switch (s.defaultPolicy) {
        CarryInSlice() => _Move.carry,
        QuestDestination() => _Move.attack,
        Discretionary() => _Move.pouch,
      };

  static String? _defaultQuest(SliceLeftover s) {
    final policy = s.defaultPolicy;
    if (policy is QuestDestination) return policy.questId;
    return s.questOptions.isNotEmpty ? s.questOptions.first.questId : null;
  }

  LeftoverDestination _destination(SliceLeftover s) {
    switch (_move[s.sliceId]!) {
      case _Move.carry:
        return const CarryInSlice();
      case _Move.pouch:
        return const Discretionary();
      case _Move.attack:
        final q = _questChoice[s.sliceId];
        return q == null ? const Discretionary() : QuestDestination(q);
    }
  }

  void _confirm() {
    final tallies = <TallyResult>[
      for (final t in widget.ritual.variableTallies)
        TallyResult(
          expenseId: t.expenseId,
          actualCents: _actuals[t.expenseId] ?? t.estimateCents,
        ),
    ];
    final allocations = <SliceAllocationResult>[
      for (final s in widget.ritual.sliceLeftovers)
        SliceAllocationResult(
          sliceId: s.sliceId,
          allocations: [
            Allocation(
                destination: _destination(s), amountCents: s.leftoverCents),
          ],
        ),
    ];
    widget.onConfirm(SpoilsResult(tallies: tallies, allocations: allocations));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.ritual;
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
                if (r.variableTallies.isNotEmpty) _quartermaster(context),
                if (r.sliceLeftovers.isEmpty)
                  TextPanel(
                    title: 'No loot to divide',
                    icon: Icons.check_circle_outline,
                    child: Text('Every monster fell clean. Nothing to split.',
                        style: monoStyle(context)),
                  )
                else
                  for (var i = 0; i < r.sliceLeftovers.length; i++)
                    _turn(context, i + 1, r.sliceLeftovers[i]),
                if (r.groupFlows.isNotEmpty || r.emergencyContribs.isNotEmpty)
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
    final r = widget.ritual;
    return TextPanel(
      title: 'Dividing the spoils · '
          '${monthLabel(r.month.year, r.month.month)}',
      icon: Icons.auto_awesome,
      accent: scheme.tertiary,
      child: Text(
        'The floor is cleared. Defaults apply in ${r.daysRemaining} '
        'day${r.daysRemaining == 1 ? '' : 's'} if you leave it — but the loot '
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
          for (final t in widget.ritual.variableTallies)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  Expanded(child: Text(t.name, style: monoStyle(context))),
                  Text(money(_actuals[t.expenseId] ?? t.estimateCents),
                      style: monoStyle(context, weight: FontWeight.w700)),
                  TextButton(
                    onPressed: () => _editActual(t),
                    child: const Text('Tally'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _turn(BuildContext context, int n, SliceLeftover s) {
    final move = _move[s.sliceId]!;
    return TextPanel(
      title: 'Turn $n · ${s.name} felled',
      icon: Icons.sports_martial_arts,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${money(s.leftoverCents)} in loot to divide.',
              style: monoStyle(context, weight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_Move>(
            segments: [
              const ButtonSegment(
                value: _Move.carry,
                icon: Icon(Icons.arrow_forward, size: 16),
                label: Text('Carry'),
              ),
              ButtonSegment(
                value: _Move.attack,
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Attack'),
                enabled: s.questOptions.isNotEmpty,
              ),
              const ButtonSegment(
                value: _Move.pouch,
                icon: Icon(Icons.savings_outlined, size: 16),
                label: Text('Pouch'),
              ),
            ],
            selected: {move},
            onSelectionChanged: (sel) =>
                setState(() => _move[s.sliceId] = sel.first),
          ),
          const SizedBox(height: AppSpacing.sm),
          _outcome(context, s, move),
        ],
      ),
    );
  }

  Widget _outcome(BuildContext context, SliceLeftover s, _Move move) {
    final scheme = Theme.of(context).colorScheme;
    switch (move) {
      case _Move.carry:
        return Text(
          '→ ${money(s.leftoverCents)} carried whole into next floor\'s '
          '${s.name}. Its limit rises.',
          style: monoStyle(context, color: scheme.primary),
        );
      case _Move.pouch:
        final split =
            previewDiscretionary(s.leftoverCents, s.poolTithePct);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('→ ${money(split.vaultCents)} to your gold pouch.',
                style: monoStyle(context, color: scheme.tertiary)),
            if (split.titheCents > 0)
              Text(
                '   ${money(split.titheCents)} tithed to the war chest '
                '(${s.poolTithePct}%).',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
          ],
        );
      case _Move.attack:
        if (s.questOptions.isEmpty) {
          return Text('No quest boss to strike.',
              style: monoStyle(context, color: scheme.onSurfaceVariant));
        }
        final qid = _questChoice[s.sliceId] ?? s.questOptions.first.questId;
        final quest = s.questOptions.firstWhere((q) => q.questId == qid,
            orElse: () => s.questOptions.first);
        final split = previewQuestAttack(
          s.leftoverCents,
          s.poolTithePct,
          sliceMainCategoryId: s.mainCategoryId,
          questMainCategoryId: quest.mainCategoryId,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButton<String>(
              value: qid,
              isDense: true,
              onChanged: (v) =>
                  setState(() => _questChoice[s.sliceId] = v),
              items: [
                for (final q in s.questOptions)
                  DropdownMenuItem(value: q.questId, child: Text(q.name)),
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
                'flies off (${s.poolTithePct}%).',
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
          for (final g in widget.ritual.groupFlows)
            Text('· ${g.name}: ${money(g.leftoverCents)} → the war chest',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
          for (final e in widget.ritual.emergencyContribs)
            Text('· ${e.fundName}: ${money(e.amountCents)} → a reserve cache',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _editActual(VariableTally t) async {
    final controller = TextEditingController(
      text: Money(_actuals[t.expenseId] ?? t.estimateCents).format(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.name),
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
      setState(() => _actuals[t.expenseId] = result);
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
