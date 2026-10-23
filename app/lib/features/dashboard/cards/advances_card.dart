part of '../dashboard_view.dart';

/// Pending requests to borrow from a budget's future months. Surfaced here so
/// the adult who has to approve sees them without hunting through the war
/// chest; the requester sees theirs waiting, with a way to withdraw it.
class _AdvancesCard extends StatelessWidget {
  const _AdvancesCard({required this.advances, required this.callbacks});

  final List<PendingAdvance> advances;
  final DashboardCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final forMe = advances.where((advance) => advance.canApprove).length;
    return AppCard(
      color: forMe > 0 ? scheme.primaryContainer : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Borrowing requests',
            icon: Icons.handshake_outlined,
            iconColor: forMe > 0 ? scheme.onPrimaryContainer : null,
          ),
          if (forMe > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                forMe == 1
                    ? 'One request is waiting for your approval.'
                    : '$forMe requests are waiting for your approval.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
              ),
            ),
          for (final advance in advances)
            PendingAdvanceTile(
              advance: advance,
              onApprove: callbacks.onApproveAdvance,
              onCancel: callbacks.onCancelAdvance,
            ),
        ],
      ),
    );
  }
}
