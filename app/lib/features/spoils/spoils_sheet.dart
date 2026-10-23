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
import '../../domain/pools.dart';
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
/// leftover so the allocation always sums exactly. The overbudget choice is
/// the one two-line case: it pays exactly what the debt needs and converts
/// the rest to discretionary, still summing to the whole leftover.
enum _Dest { overbudget, carry, quest, discretionary }

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
    for (final tally in widget.ritual.variableTallies) tally.expenseId: tally.estimateCents,
  };

  /// Chosen destination per slice. With an OVERBUDGET outstanding, paying it
  /// starts selected — the debt must be dealt with, and skipping it is an
  /// explicit choice. Otherwise the slice's configured default policy leads,
  /// so a quick confirm mirrors what the reducer would do anyway.
  late final Map<String, _Dest> _dest = {
    for (final leftover in widget.ritual.sliceLeftovers)
      leftover.sliceId: leftover.overbudgetOptions.isNotEmpty
          ? _Dest.overbudget
          : _destOf(leftover.defaultPolicy),
  };

  /// Chosen quest per slice when the destination is a quest.
  late final Map<String, String?> _questChoice = {
    for (final leftover in widget.ritual.sliceLeftovers) leftover.sliceId: _defaultQuest(leftover),
  };

  /// Chosen OVERBUDGET per slice when the destination is a debt payment.
  late final Map<String, String?> _overbudgetChoice = {
    for (final leftover in widget.ritual.sliceLeftovers)
      leftover.sliceId: leftover.overbudgetOptions.isNotEmpty
          ? leftover.overbudgetOptions.first.sliceId
          : null,
  };

  /// Savings rules only: where each category's savings go at month end. Null
  /// (the default) keeps them saved, untouched and untaxed.
  late final Map<String, _Dest?> _savingsDest = {
    for (final leftover in widget.ritual.sliceLeftovers) leftover.sliceId: null,
  };

  static _Dest _destOf(LeftoverDestination destination) => switch (destination) {
    CarryInSlice() => _Dest.carry,
    QuestDestination() => _Dest.quest,
    Discretionary() => _Dest.discretionary,
    OverbudgetPayment() => _Dest.overbudget,
  };

  static String? _defaultQuest(SliceLeftover leftover) {
    final policy = leftover.defaultPolicy;
    if (policy is QuestDestination) return policy.questId;
    return leftover.questOptions.isNotEmpty ? leftover.questOptions.first.questId : null;
  }

  bool get _hasStep1 => widget.ritual.variableTallies.isNotEmpty;

  OverbudgetOption? _chosenOverbudget(SliceLeftover leftover) {
    final id = _overbudgetChoice[leftover.sliceId];
    for (final option in leftover.overbudgetOptions) {
      if (option.sliceId == id) return option;
    }
    return leftover.overbudgetOptions.isNotEmpty ? leftover.overbudgetOptions.first : null;
  }

  List<Allocation> _allocationsFor(SliceLeftover leftover) => [
    ..._allowanceAllocations(leftover),
    ..._savingsAllocations(leftover),
  ];

  /// The optional line moving a category's savings (savings rules only).
  List<Allocation> _savingsAllocations(SliceLeftover leftover) {
    final dest = _savingsDest[leftover.sliceId];
    if (!leftover.savingsRules || dest == null || leftover.savings.balanceCents <= 0) {
      return const [];
    }
    final quest = _questChoice[leftover.sliceId];
    final debt = _chosenOverbudget(leftover);
    final LeftoverDestination? target = switch (dest) {
      _Dest.discretionary => const Discretionary(),
      _Dest.quest => quest == null ? null : QuestDestination(quest),
      _Dest.overbudget => debt == null ? null : OverbudgetPayment(debt.sliceId),
      _Dest.carry => null,
    };
    if (target == null) return const [];
    return [
      Allocation(
        destination: target,
        amountCents: leftover.savings.balanceCents,
        source: AllocationSource.savings,
      ),
    ];
  }

  List<Allocation> _allowanceAllocations(SliceLeftover leftover) {
    switch (_dest[leftover.sliceId]!) {
      case _Dest.carry:
        return [
          Allocation(
            destination: const CarryInSlice(),
            amountCents: leftover.leftoverCents,
          ),
        ];
      case _Dest.discretionary:
        return [
          Allocation(
            destination: const Discretionary(),
            amountCents: leftover.leftoverCents,
          ),
        ];
      case _Dest.quest:
        final questId = _questChoice[leftover.sliceId];
        return [
          Allocation(
            destination: questId == null
                ? const Discretionary()
                : QuestDestination(questId),
            amountCents: leftover.leftoverCents,
          ),
        ];
      case _Dest.overbudget:
        final option = _chosenOverbudget(leftover);
        if (option == null) {
          return [
            Allocation(
              destination: const Discretionary(),
              amountCents: leftover.leftoverCents,
            ),
          ];
        }
        // The whole leftover goes in as one payment. The reducer tithes it
        // (unless the categories match), pays no more than the outstanding
        // debt, and hands whatever is left to the pouch — so the OVERBUDGET
        // never takes more than it needs.
        return [
          Allocation(
            destination: OverbudgetPayment(option.sliceId),
            amountCents: leftover.leftoverCents,
          ),
        ];
    }
  }

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
          allocations: _allocationsFor(leftover),
        ),
    ];
    widget.onConfirm(SpoilsResult(tallies: tallies, allocations: allocations));
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
          decoration: const InputDecoration(
            prefixText: '\$',
            labelText: 'Actual',
          ),
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ritual = widget.ritual;
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
                      Glossary.leftoverAllocated.label(
                        isAdventure: widget.isAdventure,
                      ),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${monthLabel(ritual.month.year, ritual.month.month)} · '
                      'defaults apply in ${ritual.daysRemaining} day'
                      '${ritual.daysRemaining == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed:
                    widget.onDismiss ?? () => Navigator.maybePop(context),
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
                for (final tally in ritual.variableTallies) _tallyTile(context, tally),
                const SizedBox(height: AppSpacing.lg),
              ],
              _stepLabel(
                context,
                _hasStep1 ? 2 : 1,
                'Split each budget’s leftover',
              ),
              if (ritual.sliceLeftovers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    'No personal leftovers to divide.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final leftover in ritual.sliceLeftovers) _sliceTile(context, leftover),
              if (ritual.groupFlows.isNotEmpty ||
                  ritual.emergencyContribs.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.lg),
                _readOnlySection(context, ritual),
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

  Widget _stepLabel(BuildContext context, int stepNumber, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: scheme.primary,
            child: Text(
              '$stepNumber',
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tallyTile(BuildContext context, VariableTally tally) {
    final scheme = Theme.of(context).colorScheme;
    final actual = _actuals[tally.expenseId] ?? tally.estimateCents;
    final changed = actual != tally.estimateCents;
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
                  tally.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  changed
                      ? 'estimate ${money(tally.estimateCents)}'
                      : 'estimate — tap to set the actual',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _editActual(tally),
            child: Text(money(actual)),
          ),
        ],
      ),
    );
  }

  Widget _sliceTile(BuildContext context, SliceLeftover leftover) {
    final scheme = Theme.of(context).colorScheme;
    final dest = _dest[leftover.sliceId]!;
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
                  leftover.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (leftover.petName != null)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Text(
                    leftover.petName!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              Text(
                '${money(leftover.leftoverCents)} left',
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
              if (leftover.overbudgetOptions.isNotEmpty)
                ChoiceChip(
                  label: Text(
                    // Highlight a same-main-category source: it repays with
                    // no shared-savings cut.
                    leftover.overbudgetOptions.any(
                          (option) =>
                              option.mainCategoryId != null &&
                              option.mainCategoryId == leftover.mainCategoryId,
                        )
                        ? '${Glossary.payOverbudget.label(isAdventure: widget.isAdventure)} · no cut'
                        : Glossary.payOverbudget.label(
                            isAdventure: widget.isAdventure,
                          ),
                  ),
                  selected: dest == _Dest.overbudget,
                  onSelected: (_) =>
                      setState(() => _dest[leftover.sliceId] = _Dest.overbudget),
                ),
              ChoiceChip(
                label: Text(
                  leftover.savingsRules
                      ? (widget.isAdventure
                            ? 'Stash in ${leftover.name}'
                            : 'Save in ${leftover.name}')
                      : 'Carry in category',
                ),
                selected: dest == _Dest.carry,
                onSelected: (_) =>
                    setState(() => _dest[leftover.sliceId] = _Dest.carry),
              ),
              if (leftover.questOptions.isNotEmpty)
                ChoiceChip(
                  label: Text(
                    Glossary.attackQuest.label(isAdventure: widget.isAdventure),
                  ),
                  selected: dest == _Dest.quest,
                  onSelected: (_) =>
                      setState(() => _dest[leftover.sliceId] = _Dest.quest),
                ),
              ChoiceChip(
                label: Text(
                  leftover.savingsRules
                      ? _cap(_generalNoun)
                      : (widget.isAdventure
                            ? 'Discretionary'
                            : 'Personal spending'),
                ),
                selected: dest == _Dest.discretionary,
                onSelected: (_) =>
                    setState(() => _dest[leftover.sliceId] = _Dest.discretionary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _preview(context, leftover),
          if (leftover.savingsRules && leftover.savings.balanceCents > 0)
            _savingsRow(context, leftover),
          if (leftover.priority == SlicePriority.fun &&
              leftover.overbudgetOptions.isNotEmpty &&
              dest != _Dest.overbudget)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: _previewText(
                context,
                Icons.lightbulb_outline,
                widget.isAdventure
                    ? 'A fun budget — prime loot for felling the OVERBUDGET.'
                    : 'This is a fun budget — a good place to take the '
                          'repayment from.',
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context, SliceLeftover leftover) {
    if (leftover.savingsRules) {
      return _rulesPreview(
        context,
        leftover,
        TaxedBalance(leftover.leftoverCents),
        leftover.leftoverCents,
        _dest[leftover.sliceId]!,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final dest = _dest[leftover.sliceId]!;
    switch (dest) {
      case _Dest.overbudget:
        final option = _chosenOverbudget(leftover);
        if (option == null) {
          return _previewText(
            context,
            Icons.error_outline,
            'Nothing left to repay.',
          );
        }
        final preview = previewOverbudgetPayment(
          leftover.leftoverCents,
          leftover.poolTithePct,
          outstandingCents: option.outstandingCents,
          sliceMainCategoryId: leftover.mainCategoryId,
          targetMainCategoryId: option.mainCategoryId,
        );
        final noun = widget.isAdventure
            ? 'the OVERBUDGET on'
            : 'overspending in';
        final pouch = widget.isAdventure ? 'gold pouch' : 'personal spending';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leftover.overbudgetOptions.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final debtOption in leftover.overbudgetOptions)
                      ChoiceChip(
                        label: Text(
                          '${debtOption.name}${debtOption.mainCategoryId != null && debtOption.mainCategoryId == leftover.mainCategoryId ? ' · same category' : ''}',
                        ),
                        selected: debtOption.sliceId == option.sliceId,
                        onSelected: (_) => setState(
                          () => _overbudgetChoice[leftover.sliceId] = debtOption.sliceId,
                        ),
                      ),
                  ],
                ),
              ),
            _previewText(
              context,
              Icons.gavel_outlined,
              preview.matched
                  ? '${money(preview.payCents)} pays $noun ${option.name} at full value '
                        '(same category, no cut).'
                  : '${money(preview.payCents)} pays $noun ${option.name} after '
                        '${Glossary.sharedSavingsCut(money(preview.titheCents), leftover.poolTithePct, isAdventure: widget.isAdventure)}.',
              color: scheme.error,
            ),
            _previewText(
              context,
              Icons.flag_outlined,
              preview.payCents >= option.outstandingCents
                  ? (widget.isAdventure
                        ? 'That fells the OVERBUDGET — ${option.name} unlocks.'
                        : 'That clears it — ${option.name} unlocks.')
                  : '${money(option.outstandingCents - preview.payCents)} would '
                        'remain to repay.',
            ),
            if (preview.toVaultCents > 0 || preview.excessTitheCents > 0)
              _previewText(
                context,
                Icons.savings_outlined,
                'It takes no more than it needs: ${money(preview.toVaultCents)} '
                'goes to $pouch'
                '${preview.excessTitheCents > 0 ? ' (${Glossary.sharedSavingsCut(money(preview.excessTitheCents), leftover.poolTithePct, isAdventure: widget.isAdventure)})' : ''}.',
              ),
          ],
        );
      case _Dest.carry:
        return _previewText(
          context,
          Icons.trending_up,
          '${money(leftover.leftoverCents)} raises next month’s limit for ${leftover.name}.',
        );
      case _Dest.discretionary:
        final preview = previewDiscretionary(leftover.leftoverCents, leftover.poolTithePct);
        final dest = widget.isAdventure ? 'gold pouch' : 'personal spending';
        return _previewText(
          context,
          Icons.savings_outlined,
          '${money(preview.vaultCents)} to $dest, '
          '${Glossary.sharedSavingsCut(money(preview.titheCents), leftover.poolTithePct, isAdventure: widget.isAdventure)}.',
        );
      case _Dest.quest:
        final questId = _questChoice[leftover.sliceId];
        QuestOption? chosenQuest;
        for (final option in leftover.questOptions) {
          if (option.questId == questId) {
            chosenQuest = option;
            break;
          }
        }
        if (chosenQuest == null) {
          return _previewText(
            context,
            Icons.flag_outlined,
            widget.isAdventure ? 'Pick a quest to attack.' : 'Pick a savings goal.',
          );
        }
        final split = previewQuestAttack(
          leftover.leftoverCents,
          leftover.poolTithePct,
          sliceMainCategoryId: leftover.mainCategoryId,
          questMainCategoryId: chosenQuest.mainCategoryId,
        );
        final after = chosenQuest.totalContributedCents + split.damageCents;
        final pct = chosenQuest.targetCents <= 0
            ? 100
            : ((after / chosenQuest.targetCents) * 100).round().clamp(0, 100);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leftover.questOptions.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final option in leftover.questOptions)
                      ChoiceChip(
                        label: Text(option.name),
                        selected: option.questId == questId,
                        onSelected: (_) =>
                            setState(() => _questChoice[leftover.sliceId] = option.questId),
                      ),
                  ],
                ),
              ),
            _previewText(
              context,
              Icons.flag_outlined,
              _questPreviewLine(split, chosenQuest.name, leftover.poolTithePct),
              color: scheme.tertiary,
            ),
            const SizedBox(height: AppSpacing.xxs),
            _previewText(
              context,
              Icons.flag_outlined,
              '${chosenQuest.name}: ${money(after)} / ${money(chosenQuest.targetCents)} ($pct%)'
              '${after >= chosenQuest.targetCents ? ' — complete!' : ''}.',
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
      final matchNote = widget.isAdventure
          ? 'Same category — untithed.'
          : 'Same category — no savings cut.';
      return '$matchNote ${money(split.damageCents)} $toward $questName.';
    }
    final cut = Glossary.sharedSavingsCut(
      money(split.titheCents),
      poolTithePct,
      isAdventure: widget.isAdventure,
    );
    return '${money(split.damageCents)} $toward $questName, $cut.';
  }

  /// "$5.00 to shared savings" (or the war chest in Adventure).
  String _taxPhrase(int cents) => widget.isAdventure
      ? '${money(cents)} to the war chest'
      : '${money(cents)} to shared savings';

  String get _generalNoun =>
      Glossary.generalSavings.label(isAdventure: widget.isAdventure);

  /// The savings-rules preview for moving [amount] out of [from] to [dest],
  /// computed with the reducer's own pool math. [prefix] labels a savings line.
  Widget _rulesPreview(
    BuildContext context,
    SliceLeftover leftover,
    TaxedBalance from,
    int amount,
    _Dest dest, {
    String prefix = '',
  }) {
    final scheme = Theme.of(context).colorScheme;
    final general = leftover.generalRatePct!;
    String withTax(String lead, int tax) =>
        tax > 0 ? '$prefix$lead, ${_taxPhrase(tax)}.' : '$prefix$lead, no tax.';
    switch (dest) {
      case _Dest.carry:
        final preview = previewMove(from, amount, leftover.poolTithePct);
        return _previewText(
          context,
          Icons.savings_outlined,
          withTax('${money(preview.keepCents)} saved in ${leftover.name}', preview.taxCents),
        );
      case _Dest.discretionary:
        final preview = previewMove(from, amount, general);
        return _previewText(
          context,
          Icons.account_balance_wallet_outlined,
          withTax('${money(preview.keepCents)} to $_generalNoun', preview.taxCents),
        );
      case _Dest.quest:
        final questId = _questChoice[leftover.sliceId];
        QuestOption? chosenQuest;
        for (final option in leftover.questOptions) {
          if (option.questId == questId) chosenQuest = option;
        }
        if (chosenQuest == null) {
          return _previewText(context, Icons.flag_outlined, 'Pick a goal.');
        }
        final rate = savingsRateFor(
          const QuestDestination(''),
          carryPct: leftover.poolTithePct,
          generalPct: general,
          sliceMainCategoryId: leftover.mainCategoryId,
          destMainCategoryId: chosenQuest.mainCategoryId,
        );
        final preview = previewMove(from, amount, rate);
        final after = chosenQuest.totalContributedCents + preview.keepCents;
        final pct = chosenQuest.targetCents <= 0
            ? 100
            : ((after / chosenQuest.targetCents) * 100).round().clamp(0, 100);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prefix.isEmpty && leftover.questOptions.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final option in leftover.questOptions)
                      ChoiceChip(
                        label: Text(option.name),
                        selected: option.questId == questId,
                        onSelected: (_) =>
                            setState(() => _questChoice[leftover.sliceId] = option.questId),
                      ),
                  ],
                ),
              ),
            _previewText(
              context,
              Icons.flag_outlined,
              withTax('${money(preview.keepCents)} toward ${chosenQuest.name}', preview.taxCents),
              color: scheme.tertiary,
            ),
            _previewText(
              context,
              Icons.flag_outlined,
              '${chosenQuest.name}: ${money(after)} / ${money(chosenQuest.targetCents)} ($pct%)'
              '${after >= chosenQuest.targetCents ? ' — complete!' : ''}.',
            ),
          ],
        );
      case _Dest.overbudget:
        final option = _chosenOverbudget(leftover);
        if (option == null) {
          return _previewText(
            context,
            Icons.error_outline,
            'Nothing left to repay.',
          );
        }
        final rate = savingsRateFor(
          OverbudgetPayment(option.sliceId),
          carryPct: leftover.poolTithePct,
          generalPct: general,
          sliceMainCategoryId: leftover.mainCategoryId,
          destMainCategoryId: option.mainCategoryId,
          provisions: option.provisions,
        );
        final preview = previewSavingsOverbudget(
          from,
          amount,
          ratePct: rate,
          generalPct: general,
          outstandingCents: option.outstandingCents,
        );
        final toGeneral = withTax(
          '${money(preview.toVaultCents)} goes to $_generalNoun',
          preview.excessTitheCents,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (prefix.isEmpty && leftover.overbudgetOptions.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final debtOption in leftover.overbudgetOptions)
                      ChoiceChip(
                        label: Text(debtOption.name),
                        selected: debtOption.sliceId == option.sliceId,
                        onSelected: (_) => setState(
                          () => _overbudgetChoice[leftover.sliceId] = debtOption.sliceId,
                        ),
                      ),
                  ],
                ),
              ),
            _previewText(
              context,
              Icons.gavel_outlined,
              withTax('${money(preview.payCents)} repays ${option.name}', preview.titheCents),
              color: scheme.error,
            ),
            _previewText(
              context,
              Icons.flag_outlined,
              preview.payCents >= option.outstandingCents
                  ? 'That clears it.'
                  : '${money(option.outstandingCents - preview.payCents)} would remain.',
            ),
            if (preview.toVaultCents > 0)
              _previewText(
                context,
                Icons.account_balance_wallet_outlined,
                'It takes no more than it needs: $toGeneral',
              ),
          ],
        );
    }
  }

  /// Savings rules: the category's savings, kept by default; optionally moved
  /// to general savings, a goal, or a repayment (paying only the difference).
  Widget _savingsRow(BuildContext context, SliceLeftover leftover) {
    final scheme = Theme.of(context).colorScheme;
    final dest = _savingsDest[leftover.sliceId];
    final noun = _cap(
      Glossary.categorySavings.label(isAdventure: widget.isAdventure),
    );
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$noun: ${money(leftover.savings.balanceCents)} — stays put, untaxed, '
            'unless you move it',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: const Text('Keep saved'),
                selected: dest == null,
                onSelected: (_) =>
                    setState(() => _savingsDest[leftover.sliceId] = null),
              ),
              ChoiceChip(
                label: Text('Move to $_generalNoun'),
                selected: dest == _Dest.discretionary,
                onSelected: (_) => setState(
                  () => _savingsDest[leftover.sliceId] = _Dest.discretionary,
                ),
              ),
              if (leftover.questOptions.isNotEmpty)
                ChoiceChip(
                  label: Text(
                    Glossary.attackQuest.label(isAdventure: widget.isAdventure),
                  ),
                  selected: dest == _Dest.quest,
                  onSelected: (_) =>
                      setState(() => _savingsDest[leftover.sliceId] = _Dest.quest),
                ),
              if (leftover.overbudgetOptions.isNotEmpty)
                ChoiceChip(
                  label: Text(
                    Glossary.payOverbudget.label(
                      isAdventure: widget.isAdventure,
                    ),
                  ),
                  selected: dest == _Dest.overbudget,
                  onSelected: (_) => setState(
                    () => _savingsDest[leftover.sliceId] = _Dest.overbudget,
                  ),
                ),
            ],
          ),
          if (dest != null) ...[
            const SizedBox(height: AppSpacing.xs),
            _rulesPreview(
              context,
              leftover,
              leftover.savings,
              leftover.savings.balanceCents,
              dest,
              prefix: 'Savings: ',
            ),
          ],
        ],
      ),
    );
  }

  Widget _previewText(
    BuildContext context,
    IconData icon,
    String text, {
    Color? color,
  }) {
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

  Widget _readOnlySection(BuildContext context, SpoilsRitual ritual) {
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
          Text('Automatic', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          for (final flow in ritual.groupFlows)
            _autoLine(
              context,
              Icons.groups_outlined,
              '${flow.name}: ${money(flow.leftoverCents)} → '
              '${Glossary.warChest.label(isAdventure: widget.isAdventure)}',
            ),
          for (final contribution in ritual.emergencyContribs)
            _autoLine(
              context,
              Icons.emergency_outlined,
              '${contribution.fundName}: ${money(contribution.amountCents)} reserved off the top',
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

String _cap(String leftover) => leftover.isEmpty ? leftover : leftover[0].toUpperCase() + leftover.substring(1);
