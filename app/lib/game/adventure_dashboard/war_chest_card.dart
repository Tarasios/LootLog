part of '../adventure_dashboard.dart';

// ===========================================================================
// War chest (pool) with writs + ransack banners.
// ===========================================================================

class WarChestCard extends StatelessWidget {
  const WarChestCard({
    super.key,
    required this.chest,
    this.callbacks = const AdventureCallbacks(),
  });

  final WarChest chest;
  final AdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'War chest',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(chest.balanceCents),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (chest.hasGoal) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (chest.pctComplete ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                '${((chest.pctComplete ?? 0) * 100).round()}% of ${money(chest.targetCents!)}',
                if (chest.monthsToGo != null)
                  'about ${chest.monthsToGo} floor${chest.monthsToGo == 1 ? '' : 's'} to go',
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final ransack in chest.ransacks) ...[
            const SizedBox(height: AppSpacing.md),
            RansackBannerView(banner: ransack),
          ],
          for (final writ in chest.writsForMe) ...[
            const SizedBox(height: AppSpacing.md),
            WritTile(writ: writ, callbacks: callbacks),
          ],
          for (final writ in chest.writsForOther) ...[
            const SizedBox(height: AppSpacing.md),
            WritTile(writ: writ, callbacks: callbacks),
          ],
        ],
      ),
    );
  }
}

class WritTile extends StatelessWidget {
  const WritTile({super.key, required this.writ, required this.callbacks});

  final Writ writ;
  final AdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = writ.needsMySignature;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: mine ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu,
                  size: 18,
                  color: mine ? scheme.onPrimaryContainer : scheme.onSurface),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mine
                      ? 'A writ awaits your signature'
                      : 'A writ awaits ${writ.byName == 'You' ? 'the other' : 'the other adventurer'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: mine
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
              ),
              Text(
                money(writ.amountCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color:
                          mine ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              '${writ.byName} · ${writ.purpose} → ${writ.destinationLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mine
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: callbacks.onDeclineWrit == null
                        ? null
                        : () => callbacks.onDeclineWrit!(writ.proposalId),
                    child: const Text('Refuse'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: callbacks.onSignWrit == null
                        ? null
                        : () => callbacks.onSignWrit!(writ.proposalId),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                    child: const Text('Sign'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RansackBannerView extends StatelessWidget {
  const RansackBannerView({super.key, required this.banner});

  final RansackBanner banner;

  @override
  Widget build(BuildContext context) {
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
                  '${money(banner.excessCents)} raided for '
                  '${banner.cacheName}'
                  '${banner.purpose.isEmpty ? '' : ' · ${banner.purpose}'}',
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
}
