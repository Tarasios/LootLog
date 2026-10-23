part of '../dashboard_view.dart';

/// An open vacation: what's spent of the trip budget and the daily allowance
/// left. Tapping opens the vacations screen.
class _VacationCard extends StatelessWidget {
  const _VacationCard({required this.vacation, this.onOpen});

  final OpenVacationCard vacation;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = vacation.warnings.isNotEmpty;
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'On vacation · ${vacation.name}',
            icon: Icons.beach_access_outlined,
            iconColor: scheme.tertiary,
            trailing: onOpen == null
                ? null
                : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ),
          _ProportionBar(
            fraction: vacation.fraction,
            fill: over ? scheme.error : scheme.tertiary,
            track: scheme.surfaceContainerHighest,
            height: 8,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${money(vacation.spentCents)} of ${money(vacation.budgetCents)} '
            'spent · ${vacation.allowanceLabel}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          for (final warning in vacation.warnings)
            Text(
              warning,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
            ),
        ],
      ),
    );
  }
}
