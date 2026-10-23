part of '../event.dart';

class VariableExpenseRecorded extends Event {
  const VariableExpenseRecorded({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.expenseId,
    required this.month,
    required this.actualCents,
  });

  final String expenseId;
  final Month month;
  final int actualCents;

  @override
  String get type => 'VariableExpenseRecorded';

  @override
  Map<String, dynamic> payload() => {
    'expenseId': expenseId,
    'month': month.toKey(),
    'actualCents': actualCents,
  };
}

class LeftoverAllocated extends Event {
  const LeftoverAllocated({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.month,
    required this.sliceId,
    required this.allocations,
  });

  final String forUserId;
  final Month month;
  final String sliceId;
  final List<Allocation> allocations;

  @override
  String get type => 'LeftoverAllocated';

  @override
  Map<String, dynamic> payload() => {
    'forUserId': forUserId,
    'month': month.toKey(),
    'sliceId': sliceId,
    'allocations': [for (final allocation in allocations) allocation.toJson()],
  };
}
