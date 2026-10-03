/// The Settings card that switches on the household's savings rules (category
/// savings, general savings, borrowing from future months) and edits the
/// general savings tax afterwards.
///
/// Adopting records a `savingsRules` setting effective this month; past months
/// keep their numbers. Changing the rate later also takes effect from the
/// current month, so it never rewrites history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_card.dart';

class SavingsRulesCard extends ConsumerStatefulWidget {
  const SavingsRulesCard({super.key});

  @override
  ConsumerState<SavingsRulesCard> createState() => _SavingsRulesCardState();
}

class _SavingsRulesCardState extends ConsumerState<SavingsRulesCard> {
  final _rate = TextEditingController(text: kDefaultGeneralTithePct.toString());
  bool _busy = false;

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _adopt(int pct) async {
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    setState(() => _busy = true);
    try {
      await actions.adoptSavingsRules(
        fromMonth: Month.fromInstant(DateTime.now()),
        generalTithePct: pct,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editRate(int current) async {
    final controller = TextEditingController(text: current.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${_cap(Glossary.generalSavings.classic)} tax'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            suffixText: '%',
            helperText: 'Applies from this month on; past months keep theirs',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final n = tryParsePercent(controller.text);
              if (n != null) Navigator.of(context).pop(n);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result != current) await _adopt(result);
  }

  @override
  Widget build(BuildContext context) {
    // Watched (not just read on tap) so the actions are ready by the time the
    // button is pressed — they depend on the device setup stream.
    ref.watch(householdActionsProvider);
    final rules = ref.watch(householdStateProvider).value?.savingsRules;
    if (rules != null) {
      final now = Month.fromInstant(DateTime.now());
      final rate = rules.generalRateFor(now);
      return ListTile(
        leading: const Icon(Icons.savings_outlined),
        title: Text(_cap(Glossary.categorySavings.classic)),
        subtitle: Text(
          'Active since ${monthLabel(rules.fromMonth.year, rules.fromMonth.month)}'
          ' · ${_cap(Glossary.generalSavings.classic)} tax $rate%\n'
          '${Glossary.generalSavings.helper}',
        ),
        isThreeLine: true,
        onTap: _busy ? null : () => _editRate(rate),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _cap(Glossary.categorySavings.classic),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Unspent money can be saved inside its category, taxed once at '
              'that category’s carry tax, or moved to general savings at the '
              'general rate. Money only ever pays the difference when it '
              'moves again. Your past months stay exactly as they are.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Update LootLog on every device first — older versions can’t '
              'read the new savings records.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'General savings tax',
                suffixText: '%',
                helperText:
                    'Part of money moved to general savings that goes '
                    'to shared savings',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () {
                      final pct = tryParsePercent(_rate.text);
                      if (pct == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Enter a percentage from 0 to 100'),
                          ),
                        );
                        return;
                      }
                      _adopt(pct);
                    },
              child: const Text('Adopt from this month'),
            ),
          ],
        ),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
