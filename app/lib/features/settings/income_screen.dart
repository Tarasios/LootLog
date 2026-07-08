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
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          for (final p in setup.profiles)
            _UserIncomeCard(
              key: ValueKey(p.userId),
              userId: p.userId,
              name: names[p.userId] ?? p.name,
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
    final defaultCents = state.defaultIncomeFor(userId, currentMonth);
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
              key: ValueKey('default|$userId|${defaultCents ?? -1}'),
              name: name,
              cents: defaultCents,
              onSave: (cents) => ref
                  .read(householdActionsProvider)
                  ?.setDefaultIncome(
                    forUserId: userId,
                    amountCents: cents,
                    effectiveFromMonth: currentMonth,
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
  });

  final String name;
  final int? cents;
  final void Function(int cents) onSave;

  @override
  State<_DefaultIncomeEditor> createState() => _DefaultIncomeEditorState();
}

class _DefaultIncomeEditorState extends State<_DefaultIncomeEditor> {
  late final TextEditingController _c = TextEditingController(
    text: widget.cents != null ? Money(widget.cents!).format() : '',
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Default monthly income',
              helperText: 'Carries forward to every month until changed',
              prefixText: r'$',
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        FilledButton(
          onPressed: () {
            final cents = tryParseMoneyCents(_c.text) ?? 0;
            widget.onSave(cents);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Saved ${widget.name}\'s default income')),
            );
          },
          child: const Text('Save'),
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
