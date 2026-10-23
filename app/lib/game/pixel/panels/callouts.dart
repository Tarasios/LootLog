part of '../pixel_adventure_view.dart';

/// Call-outs above the floor: the spoils ritual, OVERBUDGET debts and
/// ransacks.
extension _CalloutsPanel on PixelAdventureView {
  Widget _spoilsCta(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: callbacks.onOpenSpoils,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.military_tech, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'The floor is cleared — divide the spoils',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overbudget(BuildContext context, OverbudgetMonster debt) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.error, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, color: scheme.onErrorContainer, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE OVERBUDGET LOOMS — ${debt.categoryName.toUpperCase()}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: scheme.onErrorContainer,
                      ),
                ),
                Text(
                  '${money(debt.outstandingCents)} HP remains'
                  '${debt.paidCents > 0 ? ' (${money(debt.paidCents)} dealt)' : ''}'
                  ' · ${debt.categoryName} is locked until it falls'
                  '${debt.mine ? '' : ' · ${debt.ownerName ?? 'ally'}’s hunt'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ransack(BuildContext context, RansackBanner ransack) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.error, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department,
              color: scheme.onErrorContainer, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE WAR CHEST WAS RANSACKED',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: scheme.onErrorContainer,
                      ),
                ),
                Text(
                  '${money(ransack.excessCents)} raided for ${ransack.cacheName}'
                  '${ransack.purpose.isEmpty ? '' : ' · ${ransack.purpose}'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
