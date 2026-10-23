/// Pure view-model for Budget setup: every adult's personal slices side by side,
/// plus the shared group slices, for a chosen household month. Derived entirely
/// from [HouseholdState] so the screen only lays it out and appends events.
library;

import '../../domain/state.dart';
import '../../domain/time.dart';

/// One slice as it appears in the setup grid for a given month.
class SetupSlice {
  const SetupSlice({
    required this.sliceId,
    required this.name,
    required this.limitCents,
    required this.effectiveLimitCents,
    required this.spentCents,
    this.petName,
  });

  final String sliceId;
  final String name;

  /// The configured monthly limit.
  final int limitCents;

  /// `limit − emergency contribution + carry-in` for this month.
  final int effectiveLimitCents;
  final int spentCents;
  final String? petName;

  int get remainingCents =>
      spentCents >= effectiveLimitCents ? 0 : effectiveLimitCents - spentCents;
}

/// One member's column: their income and personal slices for the month.
class SetupColumn {
  const SetupColumn({
    required this.userId,
    required this.incomeCents,
    required this.slices,
  });

  final String userId;
  final int incomeCents;
  final List<SetupSlice> slices;

  int get totalLimitCents =>
      slices.fold<int>(0, (sum, slice) => sum + slice.effectiveLimitCents);
}

/// The whole setup view for a month.
class BudgetSetupModel {
  const BudgetSetupModel({
    required this.month,
    required this.columns,
    required this.groupSlices,
  });

  final Month month;

  /// One column per household member, in the supplied order.
  final List<SetupColumn> columns;
  final List<SetupSlice> groupSlices;
}

BudgetSetupModel buildBudgetSetupModel(
  HouseholdState state, {
  required Month month,
  required List<String> orderedUserIds,
}) {
  SetupSlice toSetup(SliceConfig sliceConfig) {
    final sliceMonth = state.sliceMonth(sliceConfig.sliceId, month);
    return SetupSlice(
      sliceId: sliceConfig.sliceId,
      name: sliceConfig.name,
      limitCents: sliceConfig.limitCents,
      effectiveLimitCents: sliceMonth?.effectiveLimitCents ?? sliceConfig.baseEffectiveLimitCents,
      spentCents: sliceMonth?.spentCents ?? 0,
      petName: sliceConfig.petId == null ? null : state.pets[sliceConfig.petId]?.name,
    );
  }

  final personal = <String, List<SetupSlice>>{
    for (final userId in orderedUserIds) userId: <SetupSlice>[],
  };
  final group = <SetupSlice>[];
  for (final sliceConfig in state.slices.values) {
    if (sliceConfig.createdMonth.isAfter(month)) continue;
    if (sliceConfig.isGroup) {
      group.add(toSetup(sliceConfig));
    } else {
      final owner = sliceConfig.ownerUserId!;
      personal.putIfAbsent(owner, () => []).add(toSetup(sliceConfig));
    }
  }
  for (final list in personal.values) {
    list.sort((first, second) => first.name.compareTo(second.name));
  }
  group.sort((first, second) => first.name.compareTo(second.name));

  return BudgetSetupModel(
    month: month,
    columns: [
      for (final userId in orderedUserIds)
        SetupColumn(
          userId: userId,
          incomeCents: state.incomeFor(userId, month),
          slices: personal[userId] ?? const [],
        ),
    ],
    groupSlices: group,
  );
}
