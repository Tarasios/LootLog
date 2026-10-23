part of '../reducer.dart';

/// Proposals that need another adult's signature: war-chest withdrawals and
/// allowance advances. Self-approval never counts; a single-adult household
/// auto-approves.
extension _ApprovalResolution on _HouseholdStateBuilder {
  /// Resolves every withdrawal proposal. An approved one leaves the war chest
  /// in its approval month and, when directed to a vault, credits it there.
  Map<String, WithdrawalProposal> _resolveWithdrawals() {
    final withdrawals = <String, WithdrawalProposal>{};
    for (final proposal in withdrawalProposals.values) {
      var status = WithdrawalStatus.pending;
      String? approvedBy;
      Month? approvedMonth;
      if (cancelledWithdrawals.contains(proposal.proposalId)) {
        status = WithdrawalStatus.cancelled;
      } else if (_adultIds().length <= 1) {
        // Single-adult household: "another adult" is auto-satisfied.
        status = WithdrawalStatus.approved;
        approvedBy = proposal.byUserId;
        approvedMonth = proposal.occurredMonth;
      } else {
        // A DIFFERENT adult must sign; self-approval and non-adults don't count.
        final validApprovals = (withdrawalApprovals[proposal.proposalId] ?? [])
            .where(
              (approval) =>
                  approval.byUserId != proposal.byUserId &&
                  _isAdult(approval.byUserId),
            )
            .toList();
        if (validApprovals.isNotEmpty) {
          status = WithdrawalStatus.approved;
          approvedBy = validApprovals.first.byUserId;
          approvedMonth = validApprovals.first.occurredMonth;
        }
      }
      if (status == WithdrawalStatus.approved) {
        _addChest(-proposal.amountCents, approvedMonth!);
        final destination = proposal.destination;
        if (destination is UserVaultDestination) {
          _addVault(destination.userId, proposal.amountCents);
          _recordVaultFlow(
            destination.userId,
            approvedMonth,
            proposal.amountCents,
          );
        }
      }
      withdrawals[proposal.proposalId] = WithdrawalProposal(
        proposalId: proposal.proposalId,
        byUserId: proposal.byUserId,
        amountCents: proposal.amountCents,
        purpose: proposal.purpose,
        destination: proposal.destination,
        status: status,
        approvedByUserId: approvedBy,
      );
    }
    return withdrawals;
  }

  /// Resolves allowance advances (savings rules only, personal categories
  /// only). An approved advance covers spending in its month and schedules
  /// the even repayment trims over the following months.
  Map<String, AdvanceState> _resolveAdvances(SavingsRules? rules) {
    final advanceStates = <String, AdvanceState>{};
    for (final proposal in advanceProposals.values) {
      final config = slices[proposal.sliceId];
      if (rules == null ||
          !rules.appliesTo(proposal.occurredMonth) ||
          config == null ||
          config.isGroup) {
        continue;
      }
      var status = WithdrawalStatus.pending;
      String? approvedBy;
      if (cancelledAdvances.contains(proposal.advanceId)) {
        status = WithdrawalStatus.cancelled;
      } else if (_adultIds().length <= 1) {
        status = WithdrawalStatus.approved;
        approvedBy = proposal.byUserId;
      } else {
        final validApprovals = (advanceApprovals[proposal.advanceId] ?? [])
            .where(
              (approval) =>
                  approval.byUserId != proposal.byUserId &&
                  _isAdult(approval.byUserId),
            )
            .toList();
        if (validApprovals.isNotEmpty) {
          status = WithdrawalStatus.approved;
          approvedBy = validApprovals.first.byUserId;
        }
      }
      if (status == WithdrawalStatus.approved) {
        _scheduleAdvanceRepayment(proposal);
      }
      advanceStates[proposal.advanceId] = AdvanceState(
        advanceId: proposal.advanceId,
        byUserId: proposal.byUserId,
        sliceId: proposal.sliceId,
        amountCents: proposal.amountCents,
        months: proposal.months,
        month: proposal.occurredMonth,
        status: status,
        approvedByUserId: approvedBy,
        purchaseId: proposal.purchaseId,
      );
    }
    return advanceStates;
  }

  /// Books an approved advance: it covers its own month's spending, and is
  /// repaid by trims from the next [AllowanceAdvanceProposed.months]
  /// allowances.
  void _scheduleAdvanceRepayment(AllowanceAdvanceProposed proposal) {
    final coverKey = '${proposal.sliceId}|${proposal.occurredMonth.toKey()}';
    coverBySliceMonth[coverKey] =
        (coverBySliceMonth[coverKey] ?? 0) + proposal.amountCents;
    var trimMonth = proposal.occurredMonth;
    for (final trimCents in advanceTrimSchedule(
      proposal.amountCents,
      proposal.months,
    )) {
      trimMonth = trimMonth.next();
      final trimKey = '${proposal.sliceId}|${trimMonth.toKey()}';
      trimBySliceMonth[trimKey] = (trimBySliceMonth[trimKey] ?? 0) + trimCents;
    }
  }
}
