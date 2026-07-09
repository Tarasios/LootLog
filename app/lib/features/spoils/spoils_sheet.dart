/// The "dividing the spoils" ritual sheet. A dismissible, resumable two-step
/// flow over a [SpoilsRitual]: step 1 records actuals for variable recurring
/// expenses; step 2 splits each personal slice's leftover among carry-in-slice,
/// a quest, or discretionary — with a live tithe and quest-progress preview.
///
/// The view is pure: it collects the user's choices and hands back a
/// [SpoilsResult] via [onConfirm]. The screen turns that into appended events.
library;

import 'package:flutter/material.dart';

import '../../domain/money.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import 'spoils_model.dart';

/// A recorded variable actual, part of the confirmed result.
class TallyResult {
  const TallyResult({required this.expenseId, required this.actualCents});
  final String expenseId;
  final int actualCents;
}

/// A confirmed per-slice allocation, part of the result.
class SliceAllocationResult {
  const SliceAllocationResult({
    required this.sliceId,
    required this.allocations,
  });
  final String sliceId;
  final List<Allocation> allocations;
}

/// Everything the ritual produces on confirm.
class SpoilsResult {
  const SpoilsResult({required this.tallies, required this.allocations});
  final List<TallyResult> tallies;
  final List<SliceAllocationResult> allocations;
}

/// Where the whole of a slice's leftover is directed. The ritual keeps a single
/// destination per slice for a fast, legible split; the amount is the entire
/// leftover so the allocation always sums exactly.
enum _Dest { carry, quest, discretionary }

class SpoilsSheetView extends StatefulWidget {
  const SpoilsSheetView({
    super.key,
    required this.ritual,
    required this.onConfirm,
    this.onDismiss,
    this.intro,
    this.isAdventure = false,
  });

  final SpoilsRitual ritual;
  final ValueChanged<SpoilsResult> onConfirm;
  final VoidCallback? onDismiss;

  /// An optional scene rendered above the steps — the adventure skin uses it for
  /// the "settling accounts with the quartermaster" opening. Null in Classic.
  final Widget? intro;

  /// Whether the Adventure vocabulary applies. Classic (the default) speaks
  /// plain budgeting language; every flavor phrase routes through [Glossary].
  final bool isAdventure;

  @override
  State<SpoilsSheetView> createState() => _SpoilsSheetViewState();
}

class _SpoilsSheetViewState extends State<SpoilsSheetView> {
  /// Editable actuals for step 1, in cents, keyed by expenseId (starts at the
  /// estimate).
  late final Map<String, int> _actuals = {
    for (final t in widget.ritual.variableTallies) t.expenseId: t.estimateCents,
  };

  /// Chosen destination per slice (defaults to the slice's configured default
  /// policy so a quick confirm mirrors what the reducer would do anyway).
  late final Map<String, _Dest> _dest = {
    for (final s in widget.ritual.sliceLeftovers)
      s.sliceId: _destOf(s.defaultPolicy),
  };

  /// Chosen quest per slice when the destination is a quest.
  late final Map<String, String?> _questChoice = {
    for (final s in widget.ritual.sliceLeftovers)
      s.sliceId: _defaultQuest(s),
  };

  static _Dest _destOf(LeftoverDestination d) => switch (d) {
        CarryInSlice() => _Dest.carry,
        QuestDestination() => _Dest.quest,
        Discretionary() => _Dest.discretionary,
      };

  static String? _defaultQuest(SliceLeftover s) {
    final policy = s.defaultPolicy;
    if (policy is QuestDestination) return policy.questId;
    return s.questOptions.isNotEmpty ? s.questOptions.first.questId : null;
  }

  bool get _hasStep1 => widget.ritual.variableTallies.isNotEmpty;

  LeftoverDestination _destination(SliceLeftover s) {
    switch (_dest[s.sliceId]!) {
      case _Dest.carry:
        return const CarryInSlice();
      case _Dest.discretionary:
        return const Discretionary();
      case _Dest.quest:
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
              destination: _destination(s),
              amountCents: s.leftoverCents,
            ),
          ],
        ),
    ];
    widget.onConfirm(SpoilsResult(tallies: tallies, allocations: allocations));
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
          decoration: const InputDecoration(prefixText: '\$', labelText: 'Actual'),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = widget.ritual;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Glossary.leftoverAllocated
                          .label(isAdventure: widget.isAdventure),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      '${monthLabel(r.month.year, r.month.month)} · '
                      'defaults apply in ${r.daysRemaining} day'
                      '${r.daysRemaining == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onDismiss ?? () => Navigator.maybePop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss (resume later)',
              ),
            ],
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            children: [
              if (widget.intro != null) ...[
                widget.intro!,
                const SizedBox(height: AppSpacing.lg),
              ],
              if (_hasStep1) ...[
                _stepLabel(context, 1, 'Record variable actuals'),
                for (final t in r.variableTallies) _tallyTile(context, t),
                const SizedBox(height: AppSpacing.lg),
              ],
              _stepLabel(
                context,
                _hasStep1 ? 2 : 1,
                'Split each budget’s leftover',
              ),
              if (r.sliceLeftovers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No personal leftovers to divide.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              for (final s in r.sliceLeftovers) _sliceTile(context, s),
              if (r.groupFlows.isNotEmpty || r.emergencyContribs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _readOnlySection(context, r),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      widget.onDismiss ?? () => Navigator.maybePop(context),
                  child: const Text('Later'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _confirm,
                  child: const Text('Confirm the division'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepLabel(BuildContext context, int n, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: scheme.primary,
            child: Text(
              '$n',
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tallyTile(BuildContext context, VariableTally t) {
    final scheme = Theme.of(context).colorScheme;
    final actual = _actuals[t.expenseId] ?? t.estimateCents;
    final changed = actual != t.estimateCents;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  changed
                      ? 'estimate ${money(t.estimateCents)}'
                      : 'estimate — tap to set the actual',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _editActual(t),
            child: Text(money(actual)),
          ),
        ],
      ),
    );
  }

  Widget _sliceTile(BuildContext context, SliceLeftover s) {
    final scheme = Theme.of(context).colorScheme;
    final dest = _dest[s.sliceId]!;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (s.petName != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    s.petName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              Text(
                '${money(s.leftoverCents)} left',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Carry in category'),
                selected: dest == _Dest.carry,
                onSelected: (_) =>
                    setState(() => _dest[s.sliceId] = _Dest.carry),
              ),
              if (s.questOptions.isNotEmpty)
                ChoiceChip(
                  label: Text(Glossary.attackQuest
                      .label(isAdventure: widget.isAdventure)),
                  selected: dest == _Dest.quest,
                  onSelected: (_) =>
                      setState(() => _dest[s.sliceId] = _Dest.quest),
                ),
              ChoiceChip(
                label: Text(widget.isAdventure
                    ? 'Discretionary'
                    : 'Personal spending'),
                selected: dest == _Dest.discretionary,
                onSelected: (_) =>
                    setState(() => _dest[s.sliceId] = _Dest.discretionary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _preview(context, s),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, SliceLeftover s) {
    final scheme = Theme.of(context).colorScheme;
    final dest = _dest[s.sliceId]!;
    switch (dest) {
      case _Dest.carry:
        return _previewText(
          context,
          Icons.trending_up,
          '${money(s.leftoverCents)} raises next month’s limit for ${s.name}.',
        );
      case _Dest.discretionary:
        final p = previewDiscretionary(s.leftoverCents, s.poolTithePct);
        final dest = widget.isAdventure ? 'gold pouch' : 'personal spending';
        return _previewText(
          context,
          Icons.savings_outlined,
          '${money(p.vaultCents)} to $dest, '
          '${Glossary.sharedSavingsCut(money(p.titheCents), s.poolTithePct, isAdventure: widget.isAdventure)}.',
        );
      case _Dest.quest:
        final qid = _questChoice[s.sliceId];
        QuestOption? q;
        for (final o in s.questOptions) {
          if (o.questId == qid) {
            q = o;
            break;
          }
        }
        if (q == null) {
          return _previewText(
            context,
            Icons.flag_outlined,
            'Pick a quest to attack.',
          );
        }
        final split = previewQuestAttack(
          s.leftoverCents,
          s.poolTithePct,
          sliceMainCategoryId: s.mainCategoryId,
          questMainCategoryId: q.mainCategoryId,
        );
        final after = q.totalContributedCents + split.damageCents;
        final pct = q.targetCents <= 0
            ? 100
            : ((after / q.targetCents) * 100).round().clamp(0, 100);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.questOptions.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final o in s.questOptions)
                      ChoiceChip(
                        label: Text(o.name),
                        selected: o.questId == qid,
                        onSelected: (_) => setState(
                          () => _questChoice[s.sliceId] = o.questId,
                        ),
                      ),
                  ],
                ),
              ),
            _previewText(
              context,
              Icons.flag_outlined,
              _questPreviewLine(split, q.name, s.poolTithePct),
              color: scheme.tertiary,
            ),
            const SizedBox(height: AppSpacing.xxs),
            _previewText(
              context,
              Icons.flag_outlined,
              '${q.name}: ${money(after)} / ${money(q.targetCents)} ($pct%)'
              '${after >= q.targetCents ? ' — complete!' : ''}.',
            ),
          ],
        );
    }
  }

  /// The line describing where a quest allocation lands. Adventure keeps the
  /// combat framing ("damage" / "tithe to war chest"); Classic states it plainly
  /// ("toward the goal" / "to shared savings").
  String _questPreviewLine(
    ({int damageCents, int titheCents, bool matched}) split,
    String questName,
    int poolTithePct,
  ) {
    final toward = widget.isAdventure ? 'damage to' : 'toward';
    if (split.matched) {
      final matchNote =
          widget.isAdventure ? 'Same category — untithed.' : 'Same category — no savings cut.';
      return '$matchNote ${money(split.damageCents)} $toward $questName.';
    }
    final cut = Glossary.sharedSavingsCut(
        money(split.titheCents), poolTithePct,
        isAdventure: widget.isAdventure);
    return '${money(split.damageCents)} $toward $questName, $cut.';
  }

  Widget _previewText(BuildContext context, IconData icon, String text,
      {Color? color}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color ?? scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Widget _readOnlySection(BuildContext context, SpoilsRitual r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Automatic',
            style: AppText.sectionLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final g in r.groupFlows)
            _autoLine(
              context,
              Icons.groups_outlined,
              '${g.name}: ${money(g.leftoverCents)} → '
              '${Glossary.warChest.label(isAdventure: widget.isAdventure)}',
            ),
          for (final e in r.emergencyContribs)
            _autoLine(
              context,
              Icons.emergency_outlined,
              '${e.fundName}: ${money(e.amountCents)} reserved off the top',
            ),
        ],
      ),
    );
  }

  Widget _autoLine(BuildContext context, IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
