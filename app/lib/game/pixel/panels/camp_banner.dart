part of '../pixel_adventure_view.dart';

/// The camp banner: the floor's month, the party around the campfire and the
/// encouragement line.
extension _CampBannerPanel on PixelAdventureView {
  Widget _campBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PixelPanel(
      title: 'The Camp — outside floor ${game.floorNumber}',
      accent: game.heroWounded ? scheme.error : scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel(game.currentMonth.year, game.currentMonth.month),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ),
              if (game.expeditionSuppliesCents > 0)
                _Pill(
                  icon: Icons.inventory_2_outlined,
                  label: '${money(game.expeditionSuppliesCents)} supplies',
                  color: scheme.tertiaryContainer,
                  onColor: scheme.onTertiaryContainer,
                ),
              // Switching to Standard lives in the app bar's shared
              // Adventure / Standard switch.
              IconButton(
                onPressed: callbacks.onSwitchToText,
                tooltip: 'Text mode',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.text_fields, size: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _campfireScene(context),
          if (campAmbience?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Center(
                child: Text(
                  campAmbience!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                game.heroWounded ? Icons.favorite : Icons.favorite_border,
                size: 18,
                color: game.heroWounded ? scheme.error : scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  game.heroWounded
                      ? 'The party took ${money(game.heroHpLostCents)} of '
                          'overspend damage'
                      : 'The party is hale — no monster broke through',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: game.heroWounded
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The party gathered around the campfire: sprite slots that render as
  /// labelled placeholders until art lands, arranged either side of the fire.
  Widget _campfireScene(BuildContext context) {
    final fire = GameSprite(
      sprite: const SpriteRef.asset(Sprites.campfire, label: 'Campfire'),
      resolver: resolver,
      scale: 2,
      animate: animate,
    );
    if (game.roster.isEmpty) return Center(child: fire);
    final left = game.roster.take((game.roster.length + 1) ~/ 2).toList();
    final right = game.roster.skip(left.length).toList();
    Widget slot(Adventurer adventurer) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: GameSprite(
            sprite: adventurer.sprite,
            resolver: resolver,
            scale: 2,
            animate: animate,
          ),
        );
    return Center(
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        alignment: WrapAlignment.center,
        children: [
          for (final adventurer in left) slot(adventurer),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: fire,
          ),
          for (final adventurer in right) slot(adventurer),
        ],
      ),
    );
  }
}
