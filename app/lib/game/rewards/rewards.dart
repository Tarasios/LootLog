/// Cosmetic reward logic — pure, Flutter-free, unit-tested like the domain.
///
/// This module is on the *display* side of the firewall. It reads the money
/// read-model ([HouseholdState]) and the event log, decides which cosmetic
/// rewards the household has earned (defeated-quest trophies, habit-streak
/// titles and badges), and computes the diff of rewards not yet recorded as
/// [GameRewardGranted] events. It NEVER moves a cent — every reward it produces
/// is decorative, granted via a cosmetic event so it syncs like everything else.
///
/// Reward ids are deterministic (`trophy:quest:<id>`, `title:daily:<n>`,
/// `badge:ritual:<n>`) so re-running the granter is idempotent and multi-device
/// convergence needs no conflict logic.
library;

import '../../domain/event.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// A cosmetic reward the household has earned. [rewardId] is the deterministic,
/// idempotency-bearing identity; [sourceRef] points at what earned it (a
/// questId, or a streak-threshold key like `daily:7`); [label] is a
/// ready-to-show description.
class EarnedReward {
  const EarnedReward({
    required this.rewardId,
    required this.kind,
    required this.sourceRef,
    required this.label,
  });

  final String rewardId;
  final RewardKind kind;
  final String sourceRef;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is EarnedReward &&
      other.rewardId == rewardId &&
      other.kind == kind &&
      other.sourceRef == sourceRef &&
      other.label == label;

  @override
  int get hashCode => Object.hash(rewardId, kind, sourceRef, label);

  @override
  String toString() => 'EarnedReward($rewardId)';
}

/// The streak thresholds that unlock rewards. Configurable so writers/designers
/// can tune the habit loop without touching detection logic.
class StreakRewardConfig {
  const StreakRewardConfig({
    this.dailyLogTitleDays = const [3, 7, 30, 100],
    this.ritualBadgeCounts = const [1, 3, 6, 12],
  });

  /// Consecutive-day purchase-logging streak lengths that each grant a title.
  final List<int> dailyLogTitleDays;

  /// Consecutive on-time month-close counts that each grant a badge.
  final List<int> ritualBadgeCounts;
}

/// A single, self-contained read-time rewards snapshot for the surfaces that
/// show habit progress and the trophy hall's "just earned" hints.
class RewardsSnapshot {
  const RewardsSnapshot({
    required this.dailyLogStreakDays,
    required this.onTimeRitualStreakMonths,
    required this.trophies,
    required this.streakRewards,
  });

  final int dailyLogStreakDays;
  final int onTimeRitualStreakMonths;

  /// One per defeated quest boss.
  final List<EarnedReward> trophies;

  /// Titles/badges reached by the current streaks.
  final List<EarnedReward> streakRewards;

  /// Every reward earned as of this snapshot.
  List<EarnedReward> get all => [...trophies, ...streakRewards];
}

/// The household-local calendar date of an [instant], as a UTC-midnight
/// `DateTime` so day arithmetic is DST-safe.
DateTime _localDate(DateTime instant) {
  final u = instant.toUtc();
  final l = u.add(vancouverUtcOffset(u));
  return DateTime.utc(l.year, l.month, l.day);
}

/// The current consecutive-day purchase-logging streak as of [asOf].
///
/// A day counts when it has at least one non-voided purchase. The streak is
/// still "alive" on a day that has not been logged yet: if today is empty but
/// yesterday has a purchase, the run is counted from yesterday. Two empty days
/// in a row (yesterday and today) means the streak has lapsed to zero.
int dailyLogStreak(HouseholdState state, {required DateTime asOf}) {
  final days = <DateTime>{
    for (final p in state.purchases.values)
      if (!p.voided) _localDate(p.occurredAt),
  };
  if (days.isEmpty) return 0;

  var cursor = _localDate(asOf);
  if (!days.contains(cursor)) {
    // Today may simply not be logged yet — fall back to yesterday.
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// The current consecutive on-time month-close streak read from the log.
///
/// A month counts as an on-time ritual when it has a [LeftoverAllocated] event
/// recorded (`createdAt`) within [graceDays] of the month ending — the same
/// grace window the reducer uses before applying default policies. The streak
/// is the run of consecutive calendar months, ending at the latest on-time
/// month, that were all closed on time. Events recorded after [asOf] are
/// ignored so the derivation is deterministic.
int onTimeRitualStreak(
  List<Event> log, {
  required DateTime asOf,
  required int graceDays,
}) {
  final onTime = <Month>{};
  for (final e in log) {
    if (e is! LeftoverAllocated) continue;
    if (e.createdAt.isAfter(asOf)) continue;
    final deadline = e.month.endInstantUtc().add(Duration(days: graceDays));
    if (!e.createdAt.isAfter(deadline)) {
      onTime.add(e.month);
    }
  }
  if (onTime.isEmpty) return 0;

  var latest = onTime.first;
  for (final m in onTime) {
    if (m.isAfter(latest)) latest = m;
  }

  var streak = 0;
  var cursor = latest;
  while (onTime.contains(cursor)) {
    streak++;
    cursor = cursor.prev();
  }
  return streak;
}

/// A trophy for every completed (and not abandoned) quest boss.
List<EarnedReward> earnedTrophies(HouseholdState state) {
  final trophies = <EarnedReward>[];
  final ids = state.quests.keys.toList()..sort();
  for (final id in ids) {
    final q = state.quests[id]!;
    if (q.completed && !q.abandoned) {
      trophies.add(EarnedReward(
        rewardId: 'trophy:quest:$id',
        kind: RewardKind.trophy,
        sourceRef: id,
        label: '${q.name} vanquished',
      ));
    }
  }
  return trophies;
}

/// The streak titles and badges the current streaks have reached.
List<EarnedReward> streakRewards({
  required int dailyStreakDays,
  required int ritualStreakMonths,
  StreakRewardConfig config = const StreakRewardConfig(),
}) {
  final rewards = <EarnedReward>[];
  for (final threshold in config.dailyLogTitleDays) {
    if (dailyStreakDays >= threshold) {
      rewards.add(EarnedReward(
        rewardId: 'title:daily:$threshold',
        kind: RewardKind.title,
        sourceRef: 'daily:$threshold',
        label: '$threshold-day logging streak',
      ));
    }
  }
  for (final threshold in config.ritualBadgeCounts) {
    if (ritualStreakMonths >= threshold) {
      rewards.add(EarnedReward(
        rewardId: 'badge:ritual:$threshold',
        kind: RewardKind.badge,
        sourceRef: 'ritual:$threshold',
        label: threshold == 1
            ? 'First on-time ritual'
            : '$threshold on-time rituals in a row',
      ));
    }
  }
  return rewards;
}

/// The full read-time rewards snapshot: streaks, trophies, and reached tiers.
RewardsSnapshot computeRewards(
  HouseholdState state,
  List<Event> log, {
  required DateTime asOf,
  StreakRewardConfig config = const StreakRewardConfig(),
}) {
  final daily = dailyLogStreak(state, asOf: asOf);
  final ritual = onTimeRitualStreak(
    log,
    asOf: asOf,
    graceDays: state.settings.spoilsGraceDays,
  );
  return RewardsSnapshot(
    dailyLogStreakDays: daily,
    onTimeRitualStreakMonths: ritual,
    trophies: earnedTrophies(state),
    streakRewards: streakRewards(
      dailyStreakDays: daily,
      ritualStreakMonths: ritual,
      config: config,
    ),
  );
}

/// Every reward currently earned (trophies + reached streak tiers).
List<EarnedReward> computeEarnedRewards(
  HouseholdState state,
  List<Event> log, {
  required DateTime asOf,
  StreakRewardConfig config = const StreakRewardConfig(),
}) {
  final snap = computeRewards(state, log, asOf: asOf, config: config);
  return snap.all;
}

/// The set of reward ids already recorded as [GameRewardGranted] events.
Set<String> grantedRewardIds(List<Event> log) => {
      for (final e in log)
        if (e is GameRewardGranted) e.rewardId,
    };

/// The earned rewards that have no matching [GameRewardGranted] event yet — the
/// set the game should append (cosmetically) to catch the ledger up. Ordering
/// follows [earned]; ids already granted are filtered out.
List<EarnedReward> ungrantedRewards(
  List<EarnedReward> earned,
  List<Event> log,
) {
  final granted = grantedRewardIds(log);
  final seen = <String>{};
  final pending = <EarnedReward>[];
  for (final r in earned) {
    if (granted.contains(r.rewardId)) continue;
    if (seen.add(r.rewardId)) pending.add(r);
  }
  return pending;
}
