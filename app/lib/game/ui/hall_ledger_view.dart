/// The few ledger facts the guild hall shows, gathered in one money-free
/// read-model: who is in the household and how each adult plays, how far each
/// savings goal has come (as a share of its goal), how many months in a row
/// this adult has saved, and whether the household can record the newer habit
/// events (no-spend check-ins and weekly reconciles).
///
/// Rule 8: savings progress is a percentage and a run of months, never an
/// amount. Nothing here carries a cent value to the screen.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_rewards.dart';
import '../../data/providers.dart';
import '../../domain/event.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../../features/household_context.dart';
import '../data/game_providers.dart';
import '../domain/ledger_inputs.dart';

/// One adult, by name, and whether they adventure or back the party as its
/// supply caravan (Standard mode).
class HallAdult {
  const HallAdult({
    required this.memberId,
    required this.name,
    required this.inAdventure,
  });

  final String memberId;
  final String name;
  final bool inAdventure;
}

/// A savings goal's progress as a whole percentage of its goal (0..100).
class HallQuest {
  const HallQuest({
    required this.questId,
    required this.name,
    required this.percent,
    required this.shared,
    this.completed = false,
  });

  final String questId;
  final String name;
  final int percent;
  final bool shared;
  final bool completed;
}

/// What the hall reads off the ledger.
class HallLedgerView {
  const HallLedgerView({
    this.meId,
    this.adults = const [],
    this.quests = const [],
    this.savingsRunMonths = 0,
    this.habitsAvailable = false,
    this.firstBudgetMonth,
  });

  /// Nothing known yet (before setup, or while the ledger loads).
  static const empty = HallLedgerView();

  /// This device's adult.
  final String? meId;

  /// Every active adult, this device's adult first.
  final List<HallAdult> adults;

  /// The savings goals this adult funds (their own and the shared ones).
  final List<HallQuest> quests;

  /// Consecutive closed months, up to the most recent, in which this adult
  /// chose to save some leftover.
  final int savingsRunMonths;

  /// Whether no-spend check-ins and weekly reconciles can be recorded (the
  /// household adopted the savings rules, so every device understands them).
  final bool habitsAvailable;

  /// The first month the household budgeted in (its earliest category). A
  /// month-end dungeon is only offered for months from this one on, so a
  /// brand-new household is never handed chests for months it never
  /// budgeted. The current month when there are no categories yet; null when
  /// unknown (no limit).
  final Month? firstBudgetMonth;

  /// [memberId]'s display name, or a neutral fallback.
  String nameOf(String memberId) {
    for (final a in adults) {
      if (a.memberId == memberId) return a.name;
    }
    return 'Adventurer';
  }
}

/// Builds the hall's ledger view. Pure: the same inputs give the same view.
HallLedgerView buildHallLedgerView({
  required HouseholdState state,
  required List<Event> log,
  required String? meId,
  required Map<String, String> names,
  required DateTime now,
}) {
  final party = partyOf(state, log);
  final adults = [
    for (final a in party.adults)
      HallAdult(
        memberId: a.memberId,
        name: names[a.memberId] ?? 'Adventurer',
        inAdventure: a.inAdventure,
      ),
  ]..sort((a, b) {
      if (a.memberId == meId) return -1;
      if (b.memberId == meId) return 1;
      return a.name.compareTo(b.name);
    });

  final quests = <HallQuest>[];
  if (meId != null) {
    final all = state.quests.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    for (final q in all) {
      if (q.abandoned || q.targetCents <= 0) continue;
      final shared = q.ownership is SharedParty;
      final mine = switch (q.ownership) {
        PersonalParty(:final userId) => userId == meId,
        SharedParty() => true,
      };
      if (!mine) continue;
      final pct = q.completed
          ? 100
          : (q.totalContributedCents * 100 ~/ q.targetCents).clamp(0, 100);
      quests.add(HallQuest(
        questId: q.questId,
        name: q.name,
        percent: pct,
        shared: shared,
        completed: q.completed,
      ));
    }
  }

  return HallLedgerView(
    meId: meId,
    adults: adults,
    quests: quests,
    savingsRunMonths:
        meId == null ? 0 : savingsRunMonths(log, meId, Month.fromInstant(now)),
    habitsAvailable: householdAcceptsNewEventTypes(state),
    firstBudgetMonth: firstBudgetMonth(state, now),
  );
}

/// The household's earliest category month, or the month of [now] when it
/// has no categories yet.
Month firstBudgetMonth(HouseholdState state, DateTime now) {
  Month? earliest;
  for (final category in state.slices.values) {
    final created = category.createdMonth;
    if (earliest == null || created.isBefore(earliest)) earliest = created;
  }
  return earliest ?? Month.fromInstant(now);
}

/// The run of consecutive saving months ending at the latest closed month
/// [personId] saved in, counted only while that run is still alive (its last
/// month is last month or the one before, so a ritual still in progress never
/// breaks it).
int savingsRunMonths(List<Event> log, String personId, Month current) {
  final saved = savingsAllocationMonths(log, personId)
      .where((m) => m.isBefore(current))
      .toSet();
  if (saved.isEmpty) return 0;
  final latest = saved.reduce((a, b) => a.isAfter(b) ? a : b);
  if (latest.isBefore(current.prev().prev())) return 0;
  var n = 0;
  for (var m = latest; saved.contains(m); m = m.prev()) {
    n++;
  }
  return n;
}

/// The hall's ledger view for this device's adult.
final hallLedgerViewProvider = Provider<HallLedgerView>((ref) {
  final state = ref.watch(householdStateProvider).value;
  final log = ref.watch(eventLogProvider).value;
  final meId = ref.watch(meUserIdProvider);
  if (state == null || log == null) return HallLedgerView(meId: meId);
  return buildHallLedgerView(
    state: state,
    log: log,
    meId: meId,
    names: ref.watch(userNamesProvider),
    now: ref.watch(gameClockProvider).now(),
  );
});
