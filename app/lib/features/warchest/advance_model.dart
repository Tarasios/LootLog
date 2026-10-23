/// Pending borrowing requests ("borrow from future months" / allowance
/// advances), projected for display. Shared by the war-chest screen and the
/// dashboard so both list the same requests with the same wording.
///
/// Pure Dart (Flutter-free). Nothing here decides who may approve: the reducer
/// rejects self-approval and auto-approves in one-adult households, so a
/// request only ever pends when another adult has to act on it.
library;

import '../../domain/state.dart';

/// One pending request to borrow from a budget's next few monthly allowances.
class PendingAdvance {
  const PendingAdvance({
    required this.advanceId,
    required this.categoryName,
    required this.byUserName,
    required this.amountCents,
    required this.months,
    required this.mine,
  });

  final String advanceId;
  final String categoryName;
  final String byUserName;
  final int amountCents;

  /// How many future months repay it.
  final int months;

  /// True when this device's adult asked for it — they can withdraw it, but
  /// only a different adult can approve it.
  final bool mine;

  /// Whether this device's adult may approve it (anyone but the requester).
  bool get canApprove => !mine;
}

/// Every pending borrowing request in [state], the ones awaiting this
/// device's adult ([meUserId]) first, then by id for a stable order.
List<PendingAdvance> buildPendingAdvances(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
}) {
  final out = <PendingAdvance>[
    for (final advance in state.advances.values)
      if (advance.status == WithdrawalStatus.pending)
        PendingAdvance(
          advanceId: advance.advanceId,
          categoryName: state.slices[advance.sliceId]?.name ?? 'a budget',
          byUserName: userNames[advance.byUserId] ?? 'Someone',
          amountCents: advance.amountCents,
          months: advance.months,
          mine: advance.byUserId == meUserId,
        ),
  ];
  out.sort((first, second) {
    final comparison = (first.mine ? 1 : 0).compareTo(second.mine ? 1 : 0);
    return comparison != 0
        ? comparison
        : first.advanceId.compareTo(second.advanceId);
  });
  return out;
}
