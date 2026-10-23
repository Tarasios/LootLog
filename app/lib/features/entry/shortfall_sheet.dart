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

  ShortfallOptions get options => widget.options;

  int get _generalAmount => options.generalAvailableCents < options.shortCents
      ? options.generalAvailableCents
      : options.shortCents;

  String _defaultSelection() {
    if (options.generalCoversIt) return 'general';
    for (final source in options.savingsSources) {
      if (source.deliveredCents >= options.shortCents) {
        return 'savings:${source.sliceId}';
      }
    }
    if (options.canBorrow) return 'borrow';
    if (options.generalAvailableCents > 0) return 'general';
    return 'leave';
  }

  ShortfallChoice _choice() {
    if (_selected == 'general') return CoverFromGeneral(_generalAmount);
    if (_selected == 'borrow') return BorrowAhead(_months);
    if (_selected.startsWith('savings:')) {
      final id = _selected.substring('savings:'.length);
      final source = options.savingsSources.firstWhere(
        (candidate) => candidate.sliceId == id,
      );
      return CoverFromSavings(id, source.moveCents);
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
    final isGoal = options.questId != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${money(options.shortCents)} short',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isGoal
                    ? 'This goal doesn’t have enough saved yet. You can top it '
                          'up from your savings.'
                    : 'This is more than ${options.sliceName ?? 'this budget'} has '
                          'left, including what’s saved in it. How should the '
                          'rest be covered?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (options.generalAvailableCents > 0)
                _option(
                  'general',
                  'From general savings',
                  options.generalCoversIt
                      ? 'You have ${money(options.generalAvailableCents)}'
                      : 'Covers ${money(_generalAmount)} of it — you have '
                            '${money(options.generalAvailableCents)}',
                ),
              for (final source in options.savingsSources)
                _option(
                  'savings:${source.sliceId}',
                  'From ${source.name} savings',
                  [
                    source.taxCents > 0
                        ? 'Moves ${money(source.moveCents)} — ${money(source.taxCents)} '
                              'to shared savings'
                        : 'Moves ${money(source.moveCents)}, no tax',
                    if (source.deliveredCents < options.shortCents)
                      'covers ${money(source.deliveredCents)} of it',
                  ].join(' · '),
                ),
              if (options.canBorrow)
                _option(
                  'borrow',
                  'Borrow from future ${options.sliceName ?? ''} months'
                      .replaceAll('  ', ' '),
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
