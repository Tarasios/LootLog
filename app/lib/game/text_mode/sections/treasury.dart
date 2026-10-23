part of '../text_adventure_view.dart';

/// The treasury: gold pouch, war chest, reserve caches, writs and guild
/// loans.
extension _TreasurySection on TextAdventureView {
  Widget _treasury(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warChest = game.warChest;
    return TextPanel(
      title: 'The Treasury',
      icon: Icons.savings_outlined,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(context, 'Gold pouch', money(game.goldPouch.balanceCents)),
          if (game.goldPouch.projectedMintCents > 0)
            _kv(context, '  · to be minted',
                '+${money(game.goldPouch.projectedMintCents)}',
                subtle: true),
          if (game.goldPouch.clampedFlag)
            Text('  (pouch reconciled to zero)',
                style: monoStyle(context, color: scheme.error)),
          const SizedBox(height: AppSpacing.xs),
          _kv(context, 'War chest', money(warChest.balanceCents)),
          if (warChest.hasGoal)
            Text(
              '  ${textBar(warChest.pctComplete ?? 0)}  '
              '${((warChest.pctComplete ?? 0) * 100).round()}% of '
              '${money(warChest.targetCents ?? 0)}'
              '${warChest.monthsToGo != null ? ' · ~${warChest.monthsToGo} floors' : ''}',
              style: monoStyle(context, color: scheme.tertiary),
            ),
          if (game.reserveCaches.isNotEmpty ||
              game.party.any((partyMember) => partyMember.reserveCaches.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Reserve caches',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
            for (final cache in game.reserveCaches)
              _kv(context, '  · ${cache.name}', money(cache.balanceCents), subtle: true),
            for (final partyMember in game.party)
              for (final cache in partyMember.reserveCaches)
                _kv(context, '  · ${cache.name} (${partyMember.name})',
                    money(cache.balanceCents),
                    subtle: true),
          ],
        ],
      ),
    );
  }

  Widget _writs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Writs Awaiting Signature',
      icon: Icons.draw_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final writ in game.warChest.writsForMe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${writ.byName} asks ${money(writ.amountCents)} for ${writ.purpose} '
                    '→ ${writ.destinationLabel}',
                    style: monoStyle(context),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => callbacks.onSignWrit?.call(writ.proposalId),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Sign'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            callbacks.onDeclineWrit?.call(writ.proposalId),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final writ in game.warChest.writsForOther)
            Text(
              'Your writ for ${money(writ.amountCents)} (${writ.purpose}) awaits '
              'another adventurer\'s signature.',
              style: monoStyle(context, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _loans(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String floors(int count) => count == 1 ? 'the next floor' : 'the next $count floors';
    return TextPanel(
      title: 'Guild Loans Awaiting a Seal',
      icon: Icons.handshake_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final loan in game.warChest.loans)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.needsMySeal
                        ? '${loan.byName} asks a guild loan of '
                            '${money(loan.amountCents)} against the '
                            '${loan.monsterName} monster, repaid over '
                            '${floors(loan.months)}.'
                        : 'Your guild loan of ${money(loan.amountCents)} '
                            '(${loan.monsterName}, over ${floors(loan.months)}) '
                            "awaits another adventurer's seal.",
                    style: loan.needsMySeal
                        ? monoStyle(context)
                        : monoStyle(context, color: scheme.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      if (loan.needsMySeal)
                        TextButton.icon(
                          onPressed: () =>
                              callbacks.onSealLoan?.call(loan.advanceId),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Seal'),
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            callbacks.onCancelLoan?.call(loan.advanceId),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(loan.needsMySeal ? 'Refuse' : 'Withdraw'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
