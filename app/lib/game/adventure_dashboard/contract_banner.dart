part of '../adventure_dashboard.dart';

// ===========================================================================
// Party contract (group slice) with a dual-colour banner.
// ===========================================================================

class ContractBanner extends StatelessWidget {
  const ContractBanner({super.key, required this.contract});

  final PartyContract contract;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = contract.enraged ? scheme.error : scheme.primary;
    final right = contract.enraged ? scheme.error : scheme.tertiary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [left, right]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.handshake_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        contract.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (contract.petName != null)
                      _Tag(label: contract.petName!, color: scheme.tertiary),
                    if (contract.enraged)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: _Tag(label: 'ENRAGED', color: scheme.error),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _HpBarView(
                  bar: contract.hp,
                  color: contract.enraged ? scheme.error : scheme.tertiary,
                  trackColor: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${money(contract.damageCents)} / '
                  '${money(contract.maxHpCents)} shared HP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
