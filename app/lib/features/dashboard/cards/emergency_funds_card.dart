part of '../dashboard_view.dart';

class _EmergencyFundsCard extends StatelessWidget {
  const _EmergencyFundsCard({required this.funds});

  final List<EmergencyFundCard> funds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: '${_plain(Glossary.emergencyFund)}s',
            icon: Icons.shield_outlined,
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final fund in funds)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: AppRadii.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.emergency_outlined,
                              size: 16, color: scheme.error),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            fund.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Text(
                        money(fund.balanceCents),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                      ),
                      if (fund.petName != null)
                        Text(
                          fund.petName!,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
