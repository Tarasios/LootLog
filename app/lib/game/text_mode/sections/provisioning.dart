part of '../text_adventure_view.dart';

/// Equipment maintenance and provisioning at floor start.
extension _ProvisioningSection on TextAdventureView {
  Widget _provisioning(BuildContext context) {
    return TextPanel(
      title: 'Equipment Maintenance & Provisioning',
      icon: Icons.build_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in game.provisioning) _provLine(context, line),
        ],
      ),
    );
  }

  Widget _provLine(BuildContext context, ProvisionLine line) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = <String>[
      if (line.shared) 'shared' else if (line.ownerName != null) line.ownerName!,
      if (line.awaitingTally) 'awaiting tally',
      if (line.isAnnualContract && line.daysUntilDue != null)
        dueCountdown(line.daysUntilDue!),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.isAnnualContract ? '${line.name} (contract)' : line.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(context),
            ),
          ),
          if (trailing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(trailing,
                  style: monoStyle(context, color: scheme.onSurfaceVariant)),
            ),
          Text(
            '−${money(line.amountCents)}',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
