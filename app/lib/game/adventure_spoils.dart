/// The adventure-skin opening scene for the "dividing the spoils" ritual.
///
/// A pure widget (renders from the classic [SpoilsRitual] view-model, so the
/// numbers are identical) that dresses the month-close as an adventure beat:
///   1. "Settling accounts with the quartermaster" — the variable-expense tally.
///   2. A defeated-monster recap — each personal slice that left loot behind.
///   3. Coin arcs — where this floor's coin-burst mints its gold (quests, the
///      gold pouch, or the war chest), plus the automatic group/reserve flows.
///
/// It sits above the (shared) interactive allocation controls; it decides
/// nothing, it only narrates. Golden-testable at rest: the coin flourishes are
/// static marks, not running animations.
library;

import 'package:flutter/material.dart';

import '../domain/value_types.dart';
import '../features/spoils/spoils_model.dart';
import '../ui/format.dart';
import '../ui/theme.dart';
import 'game_sprite.dart';
import 'game_state.dart';

/// Coin sprite used for the burst/arc flourishes.
const _coinSprite = SpriteRef.asset('coin_spin_6f.png', label: 'Gold');

class AdventureSpoilsRecap extends StatelessWidget {
  const AdventureSpoilsRecap({
    super.key,
    required this.ritual,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final SpoilsRitual ritual;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameSprite(sprite: _coinSprite, resolver: resolver, scale: 2),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'The floor is cleared',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          if (ritual.variableTallies.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _quartermaster(context),
          ],
          if (ritual.sliceLeftovers.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _recap(context),
          ],
          if (ritual.groupFlows.isNotEmpty ||
              ritual.emergencyContribs.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _autoArcs(context),
          ],
        ],
      ),
    );
  }

  Widget _quartermaster(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Settling accounts with the quartermaster',
            style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        for (final t in ritual.variableTallies)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(Icons.inventory_outlined,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${t.name} — awaiting the true tally',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Text(
                  'est. ${money(t.estimateCents)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _recap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Monsters felled — loot to divide',
            style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        for (final s in ritual.sliceLeftovers)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                GameSprite(sprite: _coinSprite, resolver: resolver, scale: 1),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    '${money(s.leftoverCents)} → ${_destinationLabel(s.defaultPolicy)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _autoArcs(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coins that arc on their own',
            style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        for (final g in ritual.groupFlows)
          _arc(context, Icons.inventory_2_outlined,
              '${g.name}: ${money(g.leftoverCents)}', 'the war chest'),
        for (final e in ritual.emergencyContribs)
          _arc(context, Icons.shield_moon_outlined,
              '${e.fundName}: ${money(e.amountCents)}', 'a reserve cache'),
      ],
    );
  }

  Widget _arc(
    BuildContext context,
    IconData icon,
    String from,
    String to,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              from,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Icon(Icons.arrow_forward, size: 14, color: scheme.tertiary),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              to,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.tertiary),
            ),
          ),
        ],
      ),
    );
  }

  static String _destinationLabel(LeftoverDestination d) => switch (d) {
        CarryInSlice() => 'next floor',
        QuestDestination() => 'a quest',
        Discretionary() => 'the pouch',
      };
}
