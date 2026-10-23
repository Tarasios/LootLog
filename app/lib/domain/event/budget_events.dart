part of '../event.dart';

class BudgetSliceSet extends Event {
  const BudgetSliceSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.sliceId,
    required this.name,
    required this.ownership,
    required this.limitCents,
    required this.poolTithePct,
    required this.defaultLeftoverPolicy,
    required this.taxDeductibleByDefault,
    this.mainCategoryId,
    this.emergencyContribution,
    this.petId,
    this.petOwnerIds = const [],
    this.priority = SlicePriority.important,
  });

  final String sliceId;
  final String name;
  final SliceOwnership ownership;

  /// The main category this budget category rolls up to (see [MainCategorySet]).
  /// Optional for wire compatibility with pre-main-category events.
  final String? mainCategoryId;
  final int limitCents;
  final int poolTithePct;
  final LeftoverDestination defaultLeftoverPolicy;
  final bool taxDeductibleByDefault;
  final EmergencyContribution? emergencyContribution;
  final String? petId;

  /// The pet members this category belongs to (their shared budget, e.g. two
  /// cats sharing "Litter"). The cost is planned against each pet's funding
  /// source ([MemberSet.fundedByUserId]) in equal parts. Empty for non-pet
  /// categories; serialized only when non-empty for wire compatibility.
  final List<String> petOwnerIds;

  /// How essential this category is (advisory; see [SlicePriority]).
  /// Serialized only when not the default, for wire compatibility.
  final SlicePriority priority;

  @override
  String get type => 'BudgetSliceSet';

  @override
  Map<String, dynamic> payload() => {
    'sliceId': sliceId,
    'name': name,
    'ownership': ownership.toJson(),
    if (mainCategoryId != null) 'mainCategoryId': mainCategoryId,
    'limitCents': limitCents,
    'poolTithePct': poolTithePct,
    'defaultLeftoverPolicy': defaultLeftoverPolicy.toJson(),
    'taxDeductibleByDefault': taxDeductibleByDefault,
    if (emergencyContribution != null)
      'emergencyContribution': emergencyContribution!.toJson(),
    if (petId != null) 'petId': petId,
    if (petOwnerIds.isNotEmpty) 'petOwnerIds': petOwnerIds,
    if (priority != SlicePriority.important) 'priority': priority.name,
  };
}

/// Declares or amends a **main category** — the coarse grouping budget
/// categories roll up to for the spend report and quest-tithe matching.
/// Last-writer-wins by [id]; the reducer seeds the eight documented defaults, so
/// this event is only needed to rename, recolour, reorder, or add one.
class MainCategorySet extends Event {
  const MainCategorySet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.id,
    required this.name,
    required this.colorArgb,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final int colorArgb;
  final int sortOrder;

  @override
  String get type => 'MainCategorySet';

  @override
  Map<String, dynamic> payload() => {
    'id': id,
    'name': name,
    'colorArgb': colorArgb,
    'sortOrder': sortOrder,
  };
}

class RecurringExpenseSet extends Event {
  const RecurringExpenseSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.expenseId,
    required this.name,
    required this.ownership,
    required this.kind,
    required this.amountCents,
    required this.startMonth,
    this.endMonth,
    this.cadence = RecurringCadence.monthly,
    this.dueDay = 1,
    this.dueMonth,
  }) : assert(dueDay >= 1 && dueDay <= 31, 'dueDay must be 1..31'),
       assert(
         dueMonth == null || (dueMonth >= 1 && dueMonth <= 12),
         'dueMonth must be 1..12',
       );

  final String expenseId;
  final String name;
  final PartyOwnership ownership;
  final RecurringKind kind;
  final int amountCents;
  final Month startMonth;
  final Month? endMonth;

  /// Monthly (full amount each month) or annual (1/12 accrued monthly).
  final RecurringCadence cadence;

  /// Day of the month the bill is due (clamped to the month's length; 31 reads
  /// as "last day of month").
  final int dueDay;

  /// For an annual expense, the calendar month (1..12) it comes due; null for
  /// monthly expenses.
  final int? dueMonth;

  @override
  String get type => 'RecurringExpenseSet';

  @override
  Map<String, dynamic> payload() => {
    'expenseId': expenseId,
    'name': name,
    'ownership': ownership.toJson(),
    'kind': kind.name,
    'cadence': cadence.name,
    'amountCents': amountCents,
    'dueDay': dueDay,
    if (dueMonth != null) 'dueMonth': dueMonth,
    'startMonth': startMonth.toKey(),
    if (endMonth != null) 'endMonth': endMonth!.toKey(),
  };
}

class IncomeSet extends Event {
  const IncomeSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.amountCents,
    required this.month,
  });

  final String forUserId;
  final int amountCents;
  final Month month;

  @override
  String get type => 'IncomeSet';

  @override
  Map<String, dynamic> payload() => {
    'forUserId': forUserId,
    'amountCents': amountCents,
    'month': month.toKey(),
  };
}

/// Sets a user's **default** monthly income, effective from
/// [effectiveFromMonth] and carried forward until a later default supersedes it.
/// A single-month [IncomeSet] overrides the resolved default for that month.
class DefaultIncomeSet extends Event {
  const DefaultIncomeSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.forUserId,
    required this.amountCents,
    required this.effectiveFromMonth,
    this.estimatedHighCents,
  });

  final String forUserId;

  /// The planning figure. For a variable earner this is the LOW end of the
  /// estimated range: budgets aim at what the month is sure to bring in.
  final int amountCents;
  final Month effectiveFromMonth;

  /// The optimistic top of an estimated income range, for display only
  /// ("$3,000 to $4,500 — planning at the low end"). Null for a fixed salary.
  /// A month that actually pays more is recorded as a plain [IncomeSet]
  /// override; nothing budget-side ever plans on this figure.
  final int? estimatedHighCents;

  @override
  String get type => 'DefaultIncomeSet';

  @override
  Map<String, dynamic> payload() => {
    'forUserId': forUserId,
    'amountCents': amountCents,
    'effectiveFromMonth': effectiveFromMonth.toKey(),
    if (estimatedHighCents != null) 'estimatedHighCents': estimatedHighCents,
  };
}

/// Sets the per-adult share table for [month]: a map of adult id to permille
/// weight. Carries forward until a later month overrides it; absent entirely,
/// shared costs split evenly. Odd cents on a shared cost go to the purchaser.
class GroupShareSet extends Event {
  const GroupShareSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.month,
    required this.shares,
  });

  final Month month;
  final Map<String, int> shares;

  @override
  String get type => 'GroupShareSet';

  @override
  Map<String, dynamic> payload() => {
    'month': month.toKey(),
    'shares': {for (final entry in shares.entries) entry.key: entry.value},
  };
}

class EmergencyFundSet extends Event {
  const EmergencyFundSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.fundId,
    required this.name,
    this.petId,
  });

  final String fundId;
  final String name;
  final String? petId;

  @override
  String get type => 'EmergencyFundSet';

  @override
  Map<String, dynamic> payload() => {
    'fundId': fundId,
    'name': name,
    if (petId != null) 'petId': petId,
  };
}
