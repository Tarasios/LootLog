part of '../pixel_adventure_view.dart';

/// The treasury: gold pouch, war chest, writs awaiting a signature and guild
/// loans.
extension _TreasuryPanel on PixelAdventureView {
  Widget _treasury(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warChest = game.warChest;
    return _PixelPanel(
      title: 'The Treasury',
      accent: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: const SpriteRef.asset(Sprites.coin, label: 'Gold'),
                resolver: resolver,
                scale: 1,
                animate: animate,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('${game.heroName}’s gold pouch',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                money(game.goldPouch.balanceCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (game.goldPouch.projectedMintCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'This floor’s spoils would mint '
                '${money(game.goldPouch.projectedMintCents)}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.inventory_2, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('War chest')),
              Text(
                money(warChest.balanceCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (warChest.hasGoal) ...[
            const SizedBox(height: AppSpacing.xs),
            _PixelHpBar(
              fraction: (warChest.pctComplete ?? 0).clamp(0.0, 1.0),
              color: scheme.primary,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${((warChest.pctComplete ?? 0) * 100).round()}% of '
              '${money(warChest.targetCents!)}'
              '${warChest.monthsToGo != null ? ' · ~${warChest.monthsToGo} floors' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final writ in warChest.writsForMe) ...[
            const SizedBox(height: AppSpacing.sm),
            _WritRow(writ: writ, callbacks: callbacks),
          ],
          for (final writ in warChest.writsForOther) ...[
            const SizedBox(height: AppSpacing.sm),
            _WritRow(writ: writ, callbacks: callbacks),
          ],
          for (final loan in warChest.loans) ...[
            const SizedBox(height: AppSpacing.sm),
            _LoanRow(loan: loan, callbacks: callbacks),
          ],
        ],
      ),
    );
  }
}

class _WritRow extends StatelessWidget {
  const _WritRow({required this.writ, required this.callbacks});

  final Writ writ;
  final PixelAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = writ.needsMySignature;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: mine ? Border.all(color: scheme.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mine
                      ? 'A writ awaits your signature'
                      : 'A writ awaits another adventurer',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(writ.amountCents),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          Text(
            '${writ.byName} · ${writ.purpose} → ${writ.destinationLabel}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (mine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: callbacks.onDeclineWrit == null
                      ? null
                      : () => callbacks.onDeclineWrit!(writ.proposalId),
                  child: const Text('Refuse'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: callbacks.onSignWrit == null
                      ? null
                      : () => callbacks.onSignWrit!(writ.proposalId),
                  // The app themes filled buttons full-width; constrain it so it
                  // sits inline in this action row.
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                  child: const Text('Sign'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Guild loan row (allowance advance awaiting another adventurer's seal).
// ===========================================================================

class _LoanRow extends StatelessWidget {
  const _LoanRow({required this.loan, required this.callbacks});

  final GuildLoan loan;
  final PixelAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final forMe = loan.needsMySeal;
    final floors = loan.months == 1 ? '1 floor' : '${loan.months} floors';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: forMe ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: forMe ? Border.all(color: scheme.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.handshake_outlined,
                  size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  forMe
                      ? 'A guild loan awaits your seal'
                      : 'Your guild loan awaits another adventurer',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(loan.amountCents),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          Text(
            '${loan.byName} · ${loan.monsterName} · repaid over $floors',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: callbacks.onCancelLoan == null
                    ? null
                    : () => callbacks.onCancelLoan!(loan.advanceId),
                child: Text(forMe ? 'Refuse' : 'Withdraw'),
              ),
              if (forMe) ...[
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: callbacks.onSealLoan == null
                      ? null
                      : () => callbacks.onSealLoan!(loan.advanceId),
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                  child: const Text('Seal'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared pixel chrome.
// ===========================================================================
