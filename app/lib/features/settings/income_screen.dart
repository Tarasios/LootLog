/// Per-user income. Each adult has an editable **default** monthly income that
/// carries forward, plus a list of recent months showing the resolved amount
/// with a "default" / "override" badge. Editing a month writes a single-month
/// override; a month is never blank while a default is in effect.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';

/// How many months (including the current one) the per-user list shows.
const _monthsShown = 12;

class IncomeScreen extends ConsumerWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (setup == null || state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final current = Month.fromInstant(DateTime.now());
    // One card per ledger-bearing adult, derived from household membership —
    // never from device-local setup — so any household size (1, 2, 5, more)
    // gets every earner listed. The device owner sorts first.
    final meId = setup.me.userId;
    final adults = state.adultIds.toList()
      ..sort((a, b) {
        final am = a == meId ? 0 : 1;
        final bm = b == meId ? 0 : 1;
        if (am != bm) return am - bm;
        return (names[a] ?? a).compareTo(names[b] ?? b);
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final id in adults)
            _UserIncomeCard(
              key: ValueKey(id),
              userId: id,
              name: names[id] ?? id,
              state: state,
              currentMonth: current,
            ),
        ],
      ),
    );
  }
}

class _UserIncomeCard extends ConsumerWidget {
  const _UserIncomeCard({
    super.key,
    required this.userId,
    required this.name,
    required this.state,
    required this.currentMonth,
  });

  final String userId;
  final String name;
  final HouseholdState state;
  final Month currentMonth;

  List<Month> get _months {
    final months = <Month>[];
    var m = currentMonth;
    for (var i = 0; i < _monthsShown; i++) {
      months.add(m);
      m = m.prev();
    }
    return months;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effective = state.effectiveIncomeDefault(userId, currentMonth);
    final defaultCents = effective?.amountCents;
    final highCents = effective?.estimatedHighCents;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _DefaultIncomeEditor(
              key: ValueKey(
                  'default|$userId|${defaultCents ?? -1}|${highCents ?? -1}'),
              name: name,
              cents: defaultCents,
              highCents: highCents,
              onSave: (cents, high) => ref
                  .read(householdActionsProvider)
                  ?.setDefaultIncome(
                    forUserId: userId,
                    amountCents: cents,
                    effectiveFromMonth: currentMonth,
                    estimatedHighCents: high,
                  ),
            ),
            const Divider(height: AppSpacing.xl),
            for (final m in _months)
              _MonthRow(
                month: m,
                cents: state.incomeFor(userId, m),
                isOverride: state.hasIncomeOverride(userId, m),
                hasDefault: state.defaultIncomeFor(userId, m) != null,
                onEdit: () => _editMonth(context, ref, m),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMonth(BuildContext context, WidgetRef ref, Month m) async {
    final cents = await showDialog<int>(
      context: context,
      builder: (_) => _OverrideDialog(
        title: '$name — ${monthLabel(m.year, m.month)}',
        initialCents: state.incomeFor(userId, m),
      ),
    );
    if (cents == null) return;
    await ref.read(householdActionsProvider)?.setIncome(
          forUserId: userId,
          month: m,
          amountCents: cents,
        );
  }
}

class _DefaultIncomeEditor extends StatefulWidget {
  const _DefaultIncomeEditor({
    super.key,
    required this.name,
    required this.cents,
    required this.onSave,
    this.highCents,
  });

  final String name;
  final int? cents;

  /// The optimistic top of an estimated range, or null for a fixed salary.
  final int? highCents;
  final void Function(int cents, int? highCents) onSave;

  @override
  State<_DefaultIncomeEditor> createState() => _DefaultIncomeEditorState();
}

class _DefaultIncomeEditorState extends State<_DefaultIncomeEditor> {
  late final TextEditingController _c = TextEditingController(
    text: widget.cents != null ? Money(widget.cents!).format() : '',
  );
  late final TextEditingController _high = TextEditingController(
    text: widget.highCents != null ? Money(widget.highCents!).format() : '',
  );
  late bool _varies = widget.highCents != null;

  @override
  void dispose() {
    _c.dispose();
    _high.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: _varies
                      ? 'Monthly income — low estimate'
                      : 'Default monthly income',
                  helperText: _varies
                      ? 'Budgets plan on this, the amount a slow month still '
                          'brings in'
                      : 'Carries forward to every month until changed',
                  prefixText: r'$',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            FilledButton(
              onPressed: () {
                final cents = tryParseMoneyCents(_c.text) ?? 0;
                final high =
                    _varies ? tryParseMoneyCents(_high.text) : null;
                widget.onSave(cents, high);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Saved ${widget.name}\'s default income')),
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Income varies month to month'),
          subtitle: const Text('Hourly, freelance, or shifting hours: plan '
              'at the low end and record what each month really paid'),
          value: _varies,
          onChanged: (v) => setState(() => _varies = v),
        ),
        if (_varies)
          TextField(
            controller: _high,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'High estimate (a good month)',
              helperText: 'Display only — anything above the low estimate '
                  'arrives as a bonus, never as a plan',
              prefixText: r'$',
            ),
          ),
      ],
    );
  }
}

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    required this.month,
    required this.cents,
    required this.isOverride,
    required this.hasDefault,
    required this.onEdit,
  });

  final Month month;
  final int cents;
  final bool isOverride;
  final bool hasDefault;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(monthLabel(month.year, month.month)),
          ),
          if (isOverride)
            const _Badge(label: 'override', tone: _BadgeTone.override)
          else if (hasDefault)
            const _Badge(label: 'default', tone: _BadgeTone.byDefault),
          const SizedBox(width: AppSpacing.md),
          SizedBox(
            width: 96,
            child: Text(
              money(cents),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Set this month',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

enum _BadgeTone { byDefault, override }

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = tone == _BadgeTone.override
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final fg = tone == _BadgeTone.override
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: fg),
      ),
    );
  }
}

class _OverrideDialog extends StatefulWidget {
  const _OverrideDialog({required this.title, required this.initialCents});

  final String title;
  final int initialCents;

  @override
  State<_OverrideDialog> createState() => _OverrideDialogState();
}

class _OverrideDialogState extends State<_OverrideDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initialCents > 0 ? Money(widget.initialCents).format() : '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Income this month',
          prefixText: r'$',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(tryParseMoneyCents(_c.text) ?? 0),
          child: const Text('Save override'),
        ),
      ],
    );
  }
}
