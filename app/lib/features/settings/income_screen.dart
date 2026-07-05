/// Per-user monthly income. Income is keyed by household month; this screen
/// edits one month at a time (defaulting to the current one) for both members.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../data/setup/local_setup.dart';
import '../../domain/money.dart';
import '../../domain/time.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';

class IncomeScreen extends ConsumerStatefulWidget {
  const IncomeScreen({super.key});

  @override
  ConsumerState<IncomeScreen> createState() => _IncomeScreenState();
}

class _IncomeScreenState extends ConsumerState<IncomeScreen> {
  Month _month = Month.fromInstant(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (setup == null || state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Income')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _MonthStepper(
            month: _month,
            onPrev: () => setState(() => _month = _month.prev()),
            onNext: () => setState(() => _month = _month.next()),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final p in setup.profiles)
            _IncomeRow(
              key: ValueKey('${p.userId}|${_month.toKey()}'),
              profile: p,
              name: names[p.userId] ?? p.name,
              cents: state.incomeFor(p.userId, _month),
              onSave: (cents) => ref
                  .read(householdActionsProvider)
                  ?.setIncome(
                      forUserId: p.userId, month: _month, amountCents: cents),
            ),
        ],
      ),
    );
  }
}

class _MonthStepper extends StatelessWidget {
  const _MonthStepper({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final Month month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(
          monthLabel(month.year, month.month),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _IncomeRow extends StatefulWidget {
  const _IncomeRow({
    super.key,
    required this.profile,
    required this.name,
    required this.cents,
    required this.onSave,
  });

  final UserProfile profile;
  final String name;
  final int cents;
  final void Function(int cents) onSave;

  @override
  State<_IncomeRow> createState() => _IncomeRowState();
}

class _IncomeRowState extends State<_IncomeRow> {
  late final TextEditingController _c =
      TextEditingController(text: widget.cents > 0 ? Money(widget.cents).format() : '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _c,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: widget.name,
                prefixText: r'$',
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          FilledButton.tonal(
            onPressed: () {
              final cents = tryParseMoneyCents(_c.text) ?? 0;
              widget.onSave(cents);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved ${widget.name}\'s income')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
