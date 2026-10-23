part of '../text_adventure_view.dart';

/// Call-outs above the floor: the spoils ritual, ransacks and the OVERBUDGET
/// debt monsters, rendered loud.
extension _CalloutsSection on TextAdventureView {
  Widget _spoilsCallout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The floor is cleared — divide the spoils',
      icon: Icons.auto_awesome,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last floor is done. Fell each monster\'s leftover loot: carry it, '
            'hurl it at a quest boss, or pocket it.',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: callbacks.onOpenSpoils,
            icon: const Icon(Icons.sports_martial_arts),
            label: const Text('Enter the battle'),
          ),
        ],
      ),
    );
  }

  Widget _ransack(BuildContext context, RansackBanner ransack) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The war chest was ransacked!',
      icon: Icons.local_fire_department,
      accent: scheme.error,
      child: Text(
        '${money(ransack.excessCents)} was torn from the war chest to cover '
        '${ransack.cacheName} (${ransack.purpose}).',
        style: monoStyle(context, color: scheme.error),
      ),
    );
  }

  Widget _overbudgets(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'THE OVERBUDGET LOOMS',
      icon: Icons.gavel_outlined,
      accent: scheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final debt in game.overbudgets) ...[
            _hpLine(
              context,
              name: 'OVERBUDGET · ${debt.categoryName}',
              bar: textBar(debt.hp.fraction),
              value: '${money(debt.paidCents)} repaid / ${money(debt.accruedCents)}',
              tag: debt.mine ? 'yours' : (debt.ownerName ?? ''),
              tint: scheme.error,
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: Text(
                '${debt.categoryName} is locked — its funding feeds the beast '
                'until ${money(debt.outstandingCents)} is repaid. Strike it at '
                'the spoils.',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
