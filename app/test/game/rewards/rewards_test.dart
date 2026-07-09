import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/state.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:duobudget/game/rewards/rewards.dart';
import 'package:flutter_test/flutter_test.dart';

const _u1 = 'u1';

class _Seq {
  int _n = 0;
  String id() => 'e${(_n++).toString().padLeft(4, '0')}';
}

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

void main() {
  final seq = _Seq();

  PurchaseAdded buy(String id, DateTime at, {bool voided = false}) => PurchaseAdded(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: at,
        createdAt: at,
        purchaseId: id,
        target: const VaultCharge(),
        amountCents: 100,
      );

  HouseholdState stateFrom(List<Event> events, DateTime asOf) =>
      reduce(events, asOf: asOf);

  group('dailyLogStreak', () {
    test('counts consecutive days ending today', () {
      final events = [
        buy('a', _day(2026, 3, 8)),
        buy('b', _day(2026, 3, 9)),
        buy('c', _day(2026, 3, 10)),
      ];
      final s = stateFrom(events, _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 3);
    });

    test('two purchases on the same day count as one day', () {
      final events = [
        buy('a', _day(2026, 3, 9)),
        buy('b', _day(2026, 3, 9)),
        buy('c', _day(2026, 3, 10)),
      ];
      final s = stateFrom(events, _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 2);
    });

    test('a gap breaks the streak', () {
      final events = [
        buy('a', _day(2026, 3, 6)),
        // gap on the 7th
        buy('b', _day(2026, 3, 8)),
        buy('c', _day(2026, 3, 9)),
        buy('d', _day(2026, 3, 10)),
      ];
      final s = stateFrom(events, _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 3);
    });

    test('streak stays alive on a not-yet-logged today', () {
      final events = [
        buy('a', _day(2026, 3, 8)),
        buy('b', _day(2026, 3, 9)),
      ];
      // Nothing logged the 10th yet — the streak still counts from the 9th.
      final s = stateFrom(events, _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 2);
    });

    test('a missed yesterday and today is a broken streak', () {
      final events = [
        buy('a', _day(2026, 3, 5)),
        buy('b', _day(2026, 3, 6)),
      ];
      final s = stateFrom(events, _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 0);
    });

    test('voided purchases do not sustain a streak', () {
      final events = <Event>[
        buy('a', _day(2026, 3, 8)),
        buy('b', _day(2026, 3, 9)),
        buy('c', _day(2026, 3, 10)),
        PurchaseVoided(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 3, 9),
          createdAt: _day(2026, 3, 9),
          purchaseId: 'b',
        ),
      ];
      final s = stateFrom(events, _day(2026, 3, 10));
      // The 9th no longer has a live purchase, so the 10th stands alone.
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 1);
    });

    test('empty ledger has a zero streak', () {
      final s = stateFrom([], _day(2026, 3, 10));
      expect(dailyLogStreak(s, asOf: _day(2026, 3, 10)), 0);
    });
  });

  group('onTimeRitualStreak', () {
    LeftoverAllocated close(Month m, DateTime recordedAt) => LeftoverAllocated(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: m.endInstantUtc().subtract(const Duration(hours: 2)),
          createdAt: recordedAt,
          forUserId: _u1,
          month: m,
          sliceId: 'hygiene',
          allocations: const [
            Allocation(destination: Discretionary(), amountCents: 0),
          ],
        );

    test('counts consecutive on-time month closes', () {
      final events = [
        close(const Month(2026, 1), _day(2026, 2, 3)),
        close(const Month(2026, 2), _day(2026, 3, 4)),
        close(const Month(2026, 3), _day(2026, 4, 2)),
      ];
      expect(
        onTimeRitualStreak(events, asOf: _day(2026, 4, 10), graceDays: 7),
        3,
      );
    });

    test('a late close breaks the streak', () {
      final events = [
        close(const Month(2026, 1), _day(2026, 2, 3)),
        // February closed on March 20 — well past the 7-day grace window after
        // the month ended (deadline ~March 8).
        close(const Month(2026, 2), _day(2026, 3, 20)),
        close(const Month(2026, 3), _day(2026, 4, 2)),
      ];
      expect(
        onTimeRitualStreak(events, asOf: _day(2026, 4, 10), graceDays: 7),
        1,
      );
    });

    test('a skipped month breaks the streak', () {
      final events = [
        close(const Month(2026, 1), _day(2026, 2, 3)),
        // February never closed.
        close(const Month(2026, 3), _day(2026, 4, 2)),
      ];
      expect(
        onTimeRitualStreak(events, asOf: _day(2026, 4, 10), graceDays: 7),
        1,
      );
    });

    test('no closes means a zero streak', () {
      expect(onTimeRitualStreak([], asOf: _day(2026, 4, 10), graceDays: 7), 0);
    });
  });

  group('earnedTrophies', () {
    QuestSet quest(String id, String name, int target) => QuestSet(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          questId: id,
          name: name,
          targetCents: target,
          ownership: const PersonalParty(_u1),
          mainCategoryId: 'entertainment',
        );

    PurchaseAdded fund(String pid, String questId, int amount, DateTime at) =>
        PurchaseAdded(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: at,
          createdAt: at,
          purchaseId: pid,
          target: const VaultCharge(),
          amountCents: amount,
        );

    test('a defeated quest yields exactly one deterministic trophy', () {
      // Fund the quest to its target via a matching-category leftover attack.
      final events = <Event>[
        BudgetSliceSet(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 1, 1),
          createdAt: _day(2026, 1, 1),
          sliceId: 'fun',
          name: 'Fun',
          ownership: const PersonalSlice(_u1),
          mainCategoryId: 'entertainment',
          limitCents: 50000,
          poolTithePct: 0,
          defaultLeftoverPolicy: const Discretionary(),
          taxDeductibleByDefault: false,
        ),
        quest('console', 'Console', 40000),
        LeftoverAllocated(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 1, 31),
          createdAt: _day(2026, 2, 2),
          forUserId: _u1,
          month: const Month(2026, 1),
          sliceId: 'fun',
          allocations: const [
            Allocation(
              destination: QuestDestination('console'),
              amountCents: 40000,
            ),
          ],
        ),
      ];
      ignore(fund);
      final s = stateFrom(events, _day(2026, 2, 15));
      expect(s.quests['console']!.completed, isTrue);

      final trophies = earnedTrophies(s);
      expect(trophies, hasLength(1));
      expect(trophies.single.rewardId, 'trophy:quest:console');
      expect(trophies.single.kind, RewardKind.trophy);
      expect(trophies.single.sourceRef, 'console');
      expect(trophies.single.label, contains('Console'));
    });

    test('an unfinished quest yields no trophy', () {
      final events = <Event>[quest('canoe', 'Canoe', 130000)];
      final s = stateFrom(events, _day(2026, 2, 15));
      expect(earnedTrophies(s), isEmpty);
    });
  });

  group('streak rewards + grant diff', () {
    test('daily-log titles and ritual badges unlock at thresholds', () {
      const config = StreakRewardConfig(
        dailyLogTitleDays: [3, 7],
        ritualBadgeCounts: [1, 3],
      );
      final rewards = streakRewards(
        dailyStreakDays: 7,
        ritualStreakMonths: 1,
        config: config,
      );
      final ids = rewards.map((r) => r.rewardId).toSet();
      expect(ids, containsAll(<String>{'title:daily:3', 'title:daily:7'}));
      expect(ids, contains('badge:ritual:1'));
      expect(ids, isNot(contains('badge:ritual:3')));
      expect(
        rewards.firstWhere((r) => r.rewardId == 'title:daily:7').kind,
        RewardKind.title,
      );
      expect(
        rewards.firstWhere((r) => r.rewardId == 'badge:ritual:1').kind,
        RewardKind.badge,
      );
    });

    test('ungrantedRewards returns only the not-yet-granted ones', () {
      final earned = <EarnedReward>[
        const EarnedReward(
          rewardId: 'trophy:quest:console',
          kind: RewardKind.trophy,
          sourceRef: 'console',
          label: 'Console vanquished',
        ),
        const EarnedReward(
          rewardId: 'title:daily:7',
          kind: RewardKind.title,
          sourceRef: 'daily:7',
          label: '7-day streak',
        ),
      ];
      final log = <Event>[
        GameRewardGranted(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 2, 1),
          createdAt: _day(2026, 2, 1),
          rewardId: 'trophy:quest:console',
          kind: RewardKind.trophy,
          sourceRef: 'console',
          grantedAt: _day(2026, 2, 1),
        ),
      ];
      final pending = ungrantedRewards(earned, log);
      expect(pending.map((r) => r.rewardId), ['title:daily:7']);
      expect(grantedRewardIds(log), {'trophy:quest:console'});
    });

    test('grants are idempotent — re-running yields nothing new', () {
      final earned = <EarnedReward>[
        const EarnedReward(
          rewardId: 'badge:ritual:1',
          kind: RewardKind.badge,
          sourceRef: 'ritual:1',
          label: 'First ritual',
        ),
      ];
      final log = <Event>[
        GameRewardGranted(
          eventId: seq.id(),
          deviceId: 'd',
          userId: _u1,
          occurredAt: _day(2026, 2, 1),
          createdAt: _day(2026, 2, 1),
          rewardId: 'badge:ritual:1',
          kind: RewardKind.badge,
          sourceRef: 'ritual:1',
          grantedAt: _day(2026, 2, 1),
        ),
      ];
      expect(ungrantedRewards(earned, log), isEmpty);
    });
  });
}

/// Silences an unused-helper lint for the fixtures kept for readability.
void ignore(Object? _) {}
