part of '../event.dart';

/// Opens or amends a **vacation** — a self-contained sub-budget for a trip,
/// drawn from a source fund (a savings quest or an emergency fund). It has its
/// own spending categories with limits, independent of the monthly budget.
/// Last-writer-wins by [vacationId]; editing re-declares the whole vacation
/// (categories keep their ids so in-progress spending stays attributed).
class VacationSet extends Event {
  const VacationSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.vacationId,
    required this.name,
    required this.fund,
    required this.startDate,
    required this.endDate,
    required this.categories,
  });

  final String vacationId;
  final String name;

  /// The source fund this vacation reserves its budget from.
  final VacationFund fund;

  /// The trip's calendar bounds (used for daily-allowance math).
  final DateTime startDate;
  final DateTime endDate;
  final List<VacationCategory> categories;

  @override
  String get type => 'VacationSet';

  @override
  Map<String, dynamic> payload() => {
    'vacationId': vacationId,
    'name': name,
    'fund': fund.toJson(),
    'startDate': startDate.toUtc().toIso8601String(),
    'endDate': endDate.toUtc().toIso8601String(),
    'categories': [for (final category in categories) category.toJson()],
  };
}

/// Closes a vacation: no further vacation charges are accepted and the unspent
/// budget (leftover) is returned to the source fund at read time.
class VacationClosed extends Event {
  const VacationClosed({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.vacationId,
  });

  final String vacationId;

  @override
  String get type => 'VacationClosed';

  @override
  Map<String, dynamic> payload() => {'vacationId': vacationId};
}
