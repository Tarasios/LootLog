/// Pure view-model for Budget setup: both members' personal slices side by side,
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
      slices.fold<int>(0, (a, s) => a + s.effectiveLimitCents);
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
  SetupSlice toSetup(SliceConfig cfg) {
    final sm = state.sliceMonth(cfg.sliceId, month);
    return SetupSlice(
      sliceId: cfg.sliceId,
      name: cfg.name,
      limitCents: cfg.limitCents,
      effectiveLimitCents: sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents,
      spentCents: sm?.spentCents ?? 0,
      petName: cfg.petId == null ? null : state.pets[cfg.petId]?.name,
    );
  }

  final personal = <String, List<SetupSlice>>{
    for (final u in orderedUserIds) u: <SetupSlice>[],
  };
  final group = <SetupSlice>[];
  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    if (cfg.isGroup) {
      group.add(toSetup(cfg));
    } else {
      final owner = cfg.ownerUserId!;
      personal.putIfAbsent(owner, () => []).add(toSetup(cfg));
    }
  }
  for (final list in personal.values) {
    list.sort((a, b) => a.name.compareTo(b.name));
  }
  group.sort((a, b) => a.name.compareTo(b.name));

  return BudgetSetupModel(
    month: month,
    columns: [
      for (final u in orderedUserIds)
        SetupColumn(
          userId: u,
          incomeCents: state.incomeFor(u, month),
          slices: personal[u] ?? const [],
        ),
    ],
    groupSlices: group,
  );
}
