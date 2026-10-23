part of '../text_adventure_view.dart';

/// The camp: the party around the fire, supplies and hero HP.
extension _CampSection on TextAdventureView {
  Widget _campHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The Camp — outside Floor ${game.floorNumber}',
      icon: Icons.local_fire_department_outlined,
      // Switching to Standard lives in the app bar's shared Adventure /
      // Standard switch, so the camp only offers the pixel presentation.
      trailing: callbacks.onSwitchToPixels == null
          ? null
          : IconButton(
              onPressed: callbacks.onSwitchToPixels,
              tooltip: 'Pixel mode',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.grid_on, size: 18),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campAmbience?.isNotEmpty == true
                ? campAmbience!
                : 'The fire crackles. '
                    '${monthLabel(game.currentMonth.year, game.currentMonth.month)}\'s '
                    'floor awaits.',
            style: monoStyle(context, color: scheme.onSurfaceVariant)
                .copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Supplies this floor: ${money(game.expeditionSuppliesCents)}',
            style: monoStyle(context),
          ),
          if (game.heroWounded)
            Text(
              'The party is wounded — ${money(game.heroHpLostCents)} HP lost to '
              'enraged monsters.',
              style: monoStyle(context, color: scheme.error),
            )
          else
            Text('The party stands unhurt.',
                style: monoStyle(context, color: scheme.tertiary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Around the campfire:',
              style: monoStyle(context, color: scheme.secondary)),
          if (game.roster.isEmpty)
            Text('No adventurers mustered yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            for (final adventurer in game.roster) _rosterLine(context, adventurer),
        ],
      ),
    );
  }

  Widget _rosterLine(BuildContext context, Adventurer adventurer) {
    final scheme = Theme.of(context).colorScheme;
    final tag = switch (adventurer.role) {
      AdventurerRole.adventurer => 'adventurer',
      AdventurerRole.companion => 'companion',
      AdventurerRole.familiar => 'familiar',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(adventurer.isMe ? '▶ ' : '· ',
                  style: monoStyle(context, color: scheme.primary)),
              Flexible(
                child: Text(
                  adventurer.name,
                  style: monoStyle(context, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('($tag${adventurer.isMe ? ', you' : ''})',
                  style: monoStyle(context, color: scheme.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              adventurer.descriptionText?.isNotEmpty == true
                  ? adventurer.descriptionText!
                  : 'An adventurer whose tale is yet unwritten.',
              style: monoStyle(context, color: scheme.onSurfaceVariant)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
