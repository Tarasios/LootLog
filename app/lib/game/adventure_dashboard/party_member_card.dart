part of '../adventure_dashboard.dart';

// ===========================================================================
// Party member (pet) owning its monsters, contracts, and reserve caches.
// ===========================================================================

class PartyMemberCard extends StatelessWidget {
  const PartyMemberCard({
    super.key,
    required this.member,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final PartyMember member;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: member.sprite,
                resolver: resolver,
                scale: 3,
                animate: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Party member',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final monster in member.monsters) ...[
            const SizedBox(height: AppSpacing.sm),
            MonsterCard(monster: monster, resolver: resolver),
          ],
          for (final contract in member.contracts) ...[
            const SizedBox(height: AppSpacing.sm),
            ContractBanner(contract: contract),
          ],
          if (member.reserveCaches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final cache in member.reserveCaches)
                  _CacheChip(cache: cache),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
