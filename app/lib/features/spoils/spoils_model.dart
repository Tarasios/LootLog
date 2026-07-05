/// The "dividing the spoils" month-close ritual, as a pure view-model derived
/// from [HouseholdState]. It answers: does the just-closed month still have
/// undecided personal-slice leftovers or untallied variable expenses, and if so,
/// what does the user need to decide before the grace period lapses and the
/// reducer applies each slice's default policy?
///
/// Pure Dart (Flutter-free). The sheet renders this; the screen turns the user's
/// choices into appended events.
library;

import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// A variable recurring expense whose actual for the closed month has not been
/// recorded yet — step 1 of the ritual.
class VariableTally {
  const VariableTally({
    required this.expenseId,
    required this.name,
    required this.estimateCents,
    required this.isShared,
    this.ownerName,
  });

  final String expenseId;
  final String name;
  final int estimateCents;
  final bool isShared;
  final String? ownerName;
}

/// A quest the slice owner may attack with leftover.
class QuestOption {
  const QuestOption({
    required this.questId,
    required this.name,
    required this.balanceCents,
    required this.targetCents,
    required this.totalContributedCents,
  });

  final String questId;
  final String name;
  final int balanceCents;
  final int targetCents;
  final int totalContributedCents;
}

/// One personal slice with an undecided leftover — step 2 of the ritual.
class SliceLeftover {
  const SliceLeftover({
    required this.sliceId,
    required this.name,
    required this.leftoverCents,
    required this.poolTithePct,
    required this.defaultPolicy,
    required this.questOptions,
    this.petName,
  });

  final String sliceId;
  final String name;
  final int leftoverCents;

  /// The per-slice pool tithe (%), applied only to the discretionary portion.
  final int poolTithePct;
  final LeftoverDestination defaultPolicy;
  final List<QuestOption> questOptions;
  final String? petName;
}

/// A read-only line: group-slice leftover flowing to the war chest.
class GroupFlow {
  const GroupFlow({required this.name, required this.leftoverCents});
  final String name;
  final int leftoverCents;
}

/// A read-only line: an automatic emergency-fund contribution off the top.
class EmergencyContribLine {
  const EmergencyContribLine({required this.fundName, required this.amountCents});
  final String fundName;
  final int amountCents;
}

/// The full ritual view-model for one closed month.
class SpoilsRitual {
  const SpoilsRitual({
    required this.month,
    required this.forUserId,
    required this.graceDeadline,
    required this.asOf,
    required this.variableTallies,
    required this.sliceLeftovers,
    required this.groupFlows,
    required this.emergencyContribs,
  });

  final Month month;
  final String forUserId;

  /// The instant at which, with no allocation, the default policy applies.
  final DateTime graceDeadline;
  final DateTime asOf;

  final List<VariableTally> variableTallies;
  final List<SliceLeftover> sliceLeftovers;
  final List<GroupFlow> groupFlows;
  final List<EmergencyContribLine> emergencyContribs;

  /// Time left before defaults apply (never negative).
  Duration get timeRemaining {
    final d = graceDeadline.difference(asOf);
    return d.isNegative ? Duration.zero : d;
  }

  /// Whole days (rounded down) left in the grace window.
  int get daysRemaining => timeRemaining.inHours ~/ 24;

  /// There is something for the user to actually do.
  bool get isActionable =>
      variableTallies.isNotEmpty || sliceLeftovers.isNotEmpty;
}

/// Builds the ritual for the most recently closed month, or returns null when
/// the grace window has passed or there is nothing left to decide.
///
/// [meUserId] is the device owner: only *their* personal slices are actionable
/// (each user divides their own spoils on their own device).
SpoilsRitual? buildSpoilsRitual(
  HouseholdState state, {
  required String meUserId,
  required Map<String, String> userNames,
  DateTime? asOf,
}) {
  final now = (asOf ?? DateTime.now()).toUtc();
  final month = Month.fromInstant(now).prev();
  final deadline =
      month.endInstantUtc().add(Duration(days: state.settings.spoilsGraceDays));

  // Past the grace window: the reducer has already applied defaults; the ritual
  // is no longer reopenable.
  if (now.isAfter(deadline)) {
    return null;
  }

  String? nameOf(String id) => userNames[id];

  // Step 1: variable recurring expenses active that month with no actual yet.
  final tallies = <VariableTally>[];
  for (final r in state.recurringExpenses.values) {
    if (r.kind != RecurringKind.variable) continue;
    if (!r.activeIn(month)) continue;
    if (state.variableActualFor(r.expenseId, month) != null) continue;
    tallies.add(VariableTally(
      expenseId: r.expenseId,
      name: r.name,
      estimateCents: r.amountCents,
      isShared: r.isShared,
      ownerName: r.ownerUserId == null ? null : nameOf(r.ownerUserId!),
    ));
  }
  tallies.sort((a, b) => a.name.compareTo(b.name));

  // Quests this user can fund.
  final questOptions = <QuestOption>[];
  for (final q in state.quests.values) {
    if (q.completed || q.abandoned) continue;
    final o = q.ownership;
    final mine =
        o is SharedParty || (o is PersonalParty && o.userId == meUserId);
    if (!mine) continue;
    questOptions.add(QuestOption(
      questId: q.questId,
      name: q.name,
      balanceCents: q.balanceCents,
      targetCents: q.targetCents,
      totalContributedCents: q.totalContributedCents,
    ));
  }
  questOptions.sort((a, b) => a.name.compareTo(b.name));

  // Step 2: my personal slices with an unresolved leftover for that month.
  final leftovers = <SliceLeftover>[];
  final groupFlows = <GroupFlow>[];
  final emergencyByFund = <String, int>{};
  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    final sm = state.sliceMonth(cfg.sliceId, month);

    if (cfg.emergencyFundId != null && cfg.emergencyContributionCents > 0) {
      emergencyByFund[cfg.emergencyFundId!] =
          (emergencyByFund[cfg.emergencyFundId!] ?? 0) +
              cfg.emergencyContributionCents;
    }

    if (cfg.isGroup) {
      final leftover = sm?.leftoverCents ?? 0;
      if (leftover > 0) {
        groupFlows.add(GroupFlow(name: cfg.name, leftoverCents: leftover));
      }
      continue;
    }
    if (cfg.ownerUserId != meUserId) continue;
    if (sm == null || sm.resolved || sm.leftoverCents <= 0) continue;
    leftovers.add(SliceLeftover(
      sliceId: cfg.sliceId,
      name: cfg.name,
      leftoverCents: sm.leftoverCents,
      poolTithePct: cfg.poolTithePct,
      defaultPolicy: cfg.defaultLeftoverPolicy,
      questOptions: questOptions,
      petName: cfg.petId == null ? null : state.pets[cfg.petId]?.name,
    ));
  }
  leftovers.sort((a, b) => a.name.compareTo(b.name));
  groupFlows.sort((a, b) => a.name.compareTo(b.name));

  final emergencyContribs = <EmergencyContribLine>[
    for (final e in emergencyByFund.entries)
      EmergencyContribLine(
        fundName: state.emergencyFunds[e.key]?.name ?? 'Reserve',
        amountCents: e.value,
      ),
  ]..sort((a, b) => a.fundName.compareTo(b.fundName));

  final ritual = SpoilsRitual(
    month: month,
    forUserId: meUserId,
    graceDeadline: deadline,
    asOf: now,
    variableTallies: tallies,
    sliceLeftovers: leftovers,
    groupFlows: groupFlows,
    emergencyContribs: emergencyContribs,
  );
  return ritual.isActionable ? ritual : null;
}

/// A single user-chosen allocation line for a slice, from the sheet.
class DraftAllocation {
  const DraftAllocation({required this.destination, required this.amountCents});
  final LeftoverDestination destination;
  final int amountCents;
}

/// Splits a discretionary [amountCents] into the vault remainder and the
/// war-chest tithe for a live preview. Floor rounding sends the floored tithe to
/// the chest; the rest is the user's — matching the reducer exactly.
({int vaultCents, int titheCents}) previewDiscretionary(
  int amountCents,
  int poolTithePct,
) {
  final t = Money.titheCents(amountCents, poolTithePct);
  return (vaultCents: t.remainderCents, titheCents: t.titheCents);
}
