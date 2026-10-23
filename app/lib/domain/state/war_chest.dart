part of '../state.dart';

/// War-chest progress toward a goal.
class GoalProgress {
  const GoalProgress({
    required this.targetCents,
    required this.pctComplete,
    required this.remainingCents,
    required this.avgNetInflowCents,
    required this.estMonthsRemaining,
  });

  final int targetCents;
  final double pctComplete;
  final int remainingCents;

  /// Trailing three-month average net pool inflow (may be ≤ 0).
  final double avgNetInflowCents;

  /// `remaining / avg`, or `null` when the average inflow is ≤ 0.
  final double? estMonthsRemaining;
}

/// The war chest (long-term shared pool).
class WarChestState {
  const WarChestState({
    required this.balanceCents,
    this.targetCents,
    this.goal,
  });

  final int balanceCents;
  final int? targetCents;
  final GoalProgress? goal;
}

enum WithdrawalStatus { pending, approved, cancelled }

/// A pool withdrawal proposal and its resolution.
class WithdrawalProposal {
  const WithdrawalProposal({
    required this.proposalId,
    required this.byUserId,
    required this.amountCents,
    required this.purpose,
    required this.destination,
    required this.status,
    this.approvedByUserId,
  });

  final String proposalId;
  final String byUserId;
  final int amountCents;
  final String purpose;
  final WithdrawalDestination destination;
  final WithdrawalStatus status;
  final String? approvedByUserId;
}

/// A request to borrow from a category's future monthly allowances to cover a
/// purchase now. Same approval rule as a war-chest withdrawal: another adult
/// signs (auto-approved in a one-adult household). Once approved it covers
/// the category in [month] and trims the next [months] allowances.
class AdvanceState {
  const AdvanceState({
    required this.advanceId,
    required this.byUserId,
    required this.sliceId,
    required this.amountCents,
    required this.months,
    required this.month,
    required this.status,
    this.approvedByUserId,
    this.purchaseId,
  });

  final String advanceId;
  final String byUserId;
  final String sliceId;
  final int amountCents;
  final int months;

  /// The month the advance covers (the proposal's month).
  final Month month;
  final WithdrawalStatus status;
  final String? approvedByUserId;
  final String? purchaseId;
}
