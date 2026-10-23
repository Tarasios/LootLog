part of '../state.dart';

/// Derived state of a named emergency fund.
class EmergencyFundState {
  const EmergencyFundState({
    required this.fundId,
    required this.name,
    required this.balanceCents,
    this.petId,
  });

  final String fundId;
  final String name;
  final int balanceCents;
  final String? petId;
}

/// A surfaced war-chest ransack: an emergency purchase drew this excess from the
/// pool without prior approval.
class RansackRecord {
  const RansackRecord({
    required this.fundId,
    required this.excessCents,
    required this.purpose,
    required this.occurredAt,
  });

  final String fundId;
  final int excessCents;
  final String purpose;
  final DateTime occurredAt;
}
