part of '../dashboard_view.dart';

class _WarChestCard extends StatelessWidget {
  const _WarChestCard({required this.card, required this.callbacks});

  final WarChestCard card;
  final DashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: _plain(Glossary.warChest),
            icon: Icons.account_balance,
            iconColor: scheme.primary,
            trailing: Text(
              money(card.balanceCents),
              style: AppText.metricValue(context),
            ),
          ),
          if (card.hasGoal) ...[
            _ProportionBar(
              fraction: (card.pctComplete ?? 0).clamp(0.0, 1.0),
              fill: scheme.primary,
              track: scheme.surfaceContainerHighest,
              height: 8,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                '${((card.pctComplete ?? 0) * 100).round()}% of ${money(card.targetCents!)}',
                if (card.monthsToGo != null)
                  'about ${card.monthsToGo} month${card.monthsToGo == 1 ? '' : 's'} to go',
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final writ in card.pendingForMe) ...[
            const SizedBox(height: AppSpacing.md),
            _WithdrawalTile(card: writ, callbacks: callbacks, needsMe: true),
          ],
          for (final writ in card.otherPending) ...[
            const SizedBox(height: AppSpacing.md),
            _WithdrawalTile(card: writ, callbacks: callbacks, needsMe: false),
          ],
          for (final ransack in card.ransacks) ...[
            const SizedBox(height: AppSpacing.md),
            _RansackTile(ransack: ransack),
          ],
        ],
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({
    required this.card,
    required this.callbacks,
    required this.needsMe,
  });

  final WithdrawalCard card;
  final DashboardCallbacks callbacks;
  final bool needsMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: needsMe ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: needsMe ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.assignment_outlined,
                size: 18,
                color: needsMe ? scheme.onPrimaryContainer : scheme.onSurface,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  needsMe
                      ? 'Withdrawal awaiting your approval'
                      : 'Withdrawal awaiting another adult’s approval',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: needsMe
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
              ),
              Text(
                money(card.amountCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: needsMe
                          ? scheme.onPrimaryContainer
                          : scheme.onSurface,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              '${card.byUserName} · ${card.purpose} → ${card.destinationLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: needsMe
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (needsMe)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton(
                    onPressed: callbacks.onCancelWithdrawal == null
                        ? null
                        : () => callbacks.onCancelWithdrawal!(card.proposalId),
                    child: const Text('Decline'),
                  ),
                  FilledButton(
                    onPressed: callbacks.onApproveWithdrawal == null
                        ? null
                        : () => callbacks.onApproveWithdrawal!(card.proposalId),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(72, 40),
                    ),
                    child: const Text('Approve'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RansackTile extends StatelessWidget {
  const _RansackTile({required this.ransack});

  final RansackCard ransack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_plain(Glossary.ransack)} from shared savings',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onErrorContainer,
                      ),
                ),
                Text(
                  '${money(ransack.excessCents)} for ${ransack.fundName}'
                  '${ransack.purpose.isEmpty ? '' : ' · ${ransack.purpose}'}',
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
