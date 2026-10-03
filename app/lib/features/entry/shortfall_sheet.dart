/// The bottom sheet quick entry shows when a purchase is bigger than what its
/// category (or savings goal) has available: cover the gap from general
/// savings, borrow from future months, top up a goal from category savings,
/// or leave it. Plain language; the tax on any move is shown before choosing.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'shortfall.dart';

/// What the user picked in the shortfall sheet.
sealed class ShortfallChoice {
  const ShortfallChoice();
}

/// Cover [amountCents] of the gap from general savings.
class CoverFromGeneral extends ShortfallChoice {
  const CoverFromGeneral(this.amountCents);
  final int amountCents;
}

/// Borrow the gap from the category's next [months] allowances.
class BorrowAhead extends ShortfallChoice {
  const BorrowAhead(this.months);
  final int months;
}

/// Move [moveCents] of a category's savings onto the goal.
class CoverFromSavings extends ShortfallChoice {
  const CoverFromSavings(this.sliceId, this.moveCents);
  final String sliceId;
  final int moveCents;
}

/// Record nothing extra.
class LeaveIt extends ShortfallChoice {
  const LeaveIt();
}

/// Shows the sheet; resolves to the choice, or null if dismissed.
Future<ShortfallChoice?> showShortfallSheet(
  BuildContext context,
  ShortfallOptions options,
) => showModalBottomSheet<ShortfallChoice>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ShortfallSheet(options: options),
);

class _ShortfallSheet extends StatefulWidget {
  const _ShortfallSheet({required this.options});

  final ShortfallOptions options;

  @override
  State<_ShortfallSheet> createState() => _ShortfallSheetState();
}

class _ShortfallSheetState extends State<_ShortfallSheet> {
  // 'general' | 'borrow' | 'savings:<sliceId>' | 'leave'
  late String _selected = _defaultSelection();
  int _months = 1;

  ShortfallOptions get o => widget.options;

  int get _generalAmount => o.generalAvailableCents < o.shortCents
      ? o.generalAvailableCents
      : o.shortCents;

  String _defaultSelection() {
    if (o.generalCoversIt) return 'general';
    for (final s in o.savingsSources) {
      if (s.deliveredCents >= o.shortCents) return 'savings:${s.sliceId}';
    }
    if (o.canBorrow) return 'borrow';
    if (o.generalAvailableCents > 0) return 'general';
    return 'leave';
  }

  ShortfallChoice _choice() {
    if (_selected == 'general') return CoverFromGeneral(_generalAmount);
    if (_selected == 'borrow') return BorrowAhead(_months);
    if (_selected.startsWith('savings:')) {
      final id = _selected.substring('savings:'.length);
      final s = o.savingsSources.firstWhere((x) => x.sliceId == id);
      return CoverFromSavings(id, s.moveCents);
    }
    return const LeaveIt();
  }

  Widget _option(
    String key,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    final selected = _selected == key;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected ? trailing : null,
      onTap: () => setState(() => _selected = key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isGoal = o.questId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${money(o.shortCents)} short',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isGoal
                    ? 'This goal doesn’t have enough saved yet. You can top it '
                          'up from your savings.'
                    : 'This is more than ${o.sliceName ?? 'this budget'} has '
                          'left, including what’s saved in it. How should the '
                          'rest be covered?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (o.generalAvailableCents > 0)
                _option(
                  'general',
                  'From general savings',
                  o.generalCoversIt
                      ? 'You have ${money(o.generalAvailableCents)}'
                      : 'Covers ${money(_generalAmount)} of it — you have '
                            '${money(o.generalAvailableCents)}',
                ),
              for (final s in o.savingsSources)
                _option(
                  'savings:${s.sliceId}',
                  'From ${s.name} savings',
                  [
                    s.taxCents > 0
                        ? 'Moves ${money(s.moveCents)} — ${money(s.taxCents)} '
                              'to shared savings'
                        : 'Moves ${money(s.moveCents)}, no tax',
                    if (s.deliveredCents < o.shortCents)
                      'covers ${money(s.deliveredCents)} of it',
                  ].join(' · '),
                ),
              if (o.canBorrow)
                _option(
                  'borrow',
                  'Borrow from future ${o.sliceName ?? ''} months'.replaceAll(
                    '  ',
                    ' ',
                  ),
                  'Another adult approves; repaid from the next $_months '
                      'month${_months == 1 ? '' : 's'} of this budget',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fewer months',
                        onPressed: _months > 1
                            ? () => setState(() => _months--)
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_months'),
                      IconButton(
                        tooltip: 'More months',
                        onPressed: _months < 12
                            ? () => setState(() => _months++)
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              _option(
                'leave',
                isGoal ? 'Leave it' : 'Leave it as overspending',
                isGoal
                    ? 'Log the rest as a separate purchase from a budget'
                    : 'Settled at month end from your other money, as usual',
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_choice()),
                child: const Text('Cover it'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
