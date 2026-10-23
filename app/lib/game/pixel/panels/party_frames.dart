part of '../pixel_adventure_view.dart';

/// Party frames: each adventurer's portrait and the health of the monsters
/// attributed to them.
extension _PartyFramesPanel on PixelAdventureView {
  Widget _partyColumn(BuildContext context) {
    if (game.roster.isEmpty) {
      return _PixelPanel(
        title: 'The Party',
        child: Text(
          'No adventurers mustered yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return _PixelPanel(
      title: 'The Party',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final adventurer in game.roster)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PartyFrame(
                adventurer: adventurer,
                stats: _statsFor(adventurer),
                resolver: resolver,
                animate: animate,
              ),
            ),
        ],
      ),
    );
  }

  /// The narrow-layout party: the same frames scrolling horizontally so the
  /// roster stays visible above the floor.
  Widget _partyStrip(BuildContext context) {
    if (game.roster.isEmpty) return _partyColumn(context);
    return _PixelPanel(
      title: 'The Party',
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: game.roster.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final adventurer = game.roster[i];
            return SizedBox(
              width: 200,
              child: _PartyFrame(
                adventurer: adventurer,
                stats: _statsFor(adventurer),
                resolver: resolver,
                animate: animate,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Aggregates the monsters attributed to [adventurer] into a health reading for the
  /// member's frame — presentation-only grouping of numbers the adapter already
  /// derived. Companions/pets with no ledger of their own read as provisioned.
  _FrameStats _statsFor(Adventurer adventurer) {
    final monsters = <Monster>[];
    if (adventurer.role == AdventurerRole.familiar) {
      for (final partyMember in game.party) {
        if (partyMember.petId == adventurer.memberId) monsters.addAll(partyMember.monsters);
      }
    } else {
      for (final monster in game.monsters) {
        final belongsToAdventurer = adventurer.isMe ? monster.mine : (!monster.mine && monster.ownerName == adventurer.name);
        if (belongsToAdventurer) monsters.add(monster);
      }
    }
    var maxHp = 0;
    var damage = 0;
    var excess = 0;
    for (final monster in monsters) {
      maxHp += monster.maxHpCents;
      damage += monster.damageCents;
      excess += monster.excessCents;
    }
    return _FrameStats(
      hasLedger: monsters.isNotEmpty,
      maxHpCents: maxHp,
      damageCents: damage,
      enraged: excess > 0,
    );
  }
}

class _FrameStats {
  const _FrameStats({
    required this.hasLedger,
    required this.maxHpCents,
    required this.damageCents,
    required this.enraged,
  });

  /// Whether this member owns any monsters (adults do; companions/pets may not).
  final bool hasLedger;
  final int maxHpCents;
  final int damageCents;
  final bool enraged;

  /// Remaining-health fraction (full when the member carries no ledger).
  double get fraction {
    if (!hasLedger || maxHpCents <= 0) return 1;
    final remaining = maxHpCents - damageCents;
    final fill = remaining / maxHpCents;
    return fill < 0 ? 0 : (fill > 1 ? 1 : fill);
  }
}

// ===========================================================================
// Party frame: a portrait, name, role and an HP bar.
// ===========================================================================

class _PartyFrame extends StatelessWidget {
  const _PartyFrame({
    required this.adventurer,
    required this.stats,
    required this.resolver,
    required this.animate,
  });

  final Adventurer adventurer;
  final _FrameStats stats;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = adventurer.isMe ? scheme.primary : scheme.outlineVariant;
    final barColor = stats.enraged ? scheme.error : scheme.primary;
    final role = switch (adventurer.role) {
      AdventurerRole.adventurer => 'adventurer',
      AdventurerRole.companion => 'companion',
      AdventurerRole.familiar => 'familiar',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: Border.all(
          color: tint,
          width: adventurer.isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          GameSprite(
            sprite: adventurer.sprite,
            resolver: resolver,
            baseSize: kPortraitBaseSize,
            scale: 1,
            animate: animate,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        adventurer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (adventurer.isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xxs),
                        child: Text('(you)',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: scheme.primary)),
                      ),
                  ],
                ),
                Text(role,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xxs),
                if (stats.hasLedger)
                  _PixelHpBar(fraction: stats.fraction, color: barColor)
                else
                  Text('provisioned',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.tertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Monster tile: a sprite sized by budget, its name and a small HP bar.
// ===========================================================================
