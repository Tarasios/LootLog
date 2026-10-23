/// One pending borrowing request with its actions, shared by the war-chest
/// screen and the dashboard. A pure widget: the caller wires [onApprove] and
/// [onCancel] to the household actions.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import 'advance_model.dart';

class PendingAdvanceTile extends StatelessWidget {
  const PendingAdvanceTile({
    super.key,
    required this.advance,
    this.onApprove,
    this.onCancel,
  });

  final PendingAdvance advance;

  /// Approves the request. Never shown to the requester — another adult has
  /// to approve (the reducer rejects self-approval).
  final void Function(String advanceId)? onApprove;

  /// Declines it (another adult) or withdraws it (the requester).
  final void Function(String advanceId)? onCancel;

  @override
  Widget build(BuildContext context) {
    final a = advance;
    final months = a.months;
    final plural = months == 1 ? '' : 's';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${money(a.amountCents)} from ${a.categoryName} over $months '
              'month$plural',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Asked by ${a.byUserName} · repaid from the next $months '
              'month$plural of that budget',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (a.mine)
                  Expanded(
                    child: Text(
                      'Waiting for another adult to approve.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                TextButton(
                  onPressed:
                      onCancel == null ? null : () => onCancel!(a.advanceId),
                  child: Text(a.mine ? 'Withdraw' : 'Decline'),
                ),
                if (a.canApprove) ...[
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: onApprove == null
                        ? null
                        : () => onApprove!(a.advanceId),
                    child: const Text('Approve'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
