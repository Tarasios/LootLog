part of '../dashboard_view.dart';

/// A loud, full-width banner for outstanding overspending to repay. Every
/// adult sees every debt; tapping opens the month wrap-up where leftovers can
/// pay it down.
class _OverbudgetBanner extends StatelessWidget {
  const _OverbudgetBanner({required this.card, this.onOpen});

  final OverbudgetCard card;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final whose = card.mine ? 'your' : '${card.ownerName ?? 'a housemate'}’s';
    return AppCard(
      color: scheme.errorContainer,
      onTap: onOpen,
      child: Row(
        children: [
          Icon(Icons.gavel_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${money(card.outstandingCents)} to repay on $whose '
                  '${card.categoryName}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  card.paidCents > 0
                      ? '${money(card.paidCents)} repaid so far — the budget '
                          'stays locked until it clears.'
                      : 'The budget stays locked until it clears. Leftovers '
                          'at the month wrap-up pay it down.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.onErrorContainer),
        ],
      ),
    );
  }
}
