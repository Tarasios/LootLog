/// The dungeon entrance: record what each variable bill actually cost. The
/// estimate is pre-filled; differences flow through savings and never
/// punish.
library;

import 'package:flutter/material.dart';

import '../../../domain/money.dart';
import '../../../features/spoils/spoils_model.dart';
import '../../../ui/format.dart';
import '../../../ui/money_input.dart';

class UpkeepStep extends StatefulWidget {
  const UpkeepStep({super.key, required this.tallies, required this.onDone, this.intro});

  final List<VariableTally> tallies;
  final void Function(Map<String, int> actualsByExpenseId) onDone;

  /// A line of game voice above the bills.
  final String? intro;

  @override
  State<UpkeepStep> createState() => _UpkeepStepState();
}

class _UpkeepStepState extends State<UpkeepStep> {
  late final Map<String, TextEditingController> _controllers = {
    for (final tally in widget.tallies)
      tally.expenseId: TextEditingController(text: Money(tally.estimateCents).format()),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _centsFor(VariableTally tally) => tryParseMoneyCents(_controllers[tally.expenseId]!.text);

  bool get _allValid => widget.tallies.every((tally) => _centsFor(tally) != null);

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: [
        if (widget.intro case final String intro) ...[
          Text(intro, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
        ],
        Text('Before you go down: what did these bills come to?', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        for (final tally in widget.tallies)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: ValueKey('upkeep-${tally.expenseId}'),
              controller: _controllers[tally.expenseId],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: tally.name,
                helperText: 'Estimate ${money(tally.estimateCents)}',
                errorText: _centsFor(tally) == null ? 'Enter an amount, like 82.50' : null,
                prefixText: r'$',
              ),
            ),
          ),
        FilledButton(
          onPressed: _allValid
              ? () => widget.onDone({for (final tally in widget.tallies) tally.expenseId: _centsFor(tally)!})
              : null,
          child: const Text('Descend'),
        ),
      ]);
}
