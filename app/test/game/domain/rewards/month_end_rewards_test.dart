import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/ledger_inputs.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/domain/rewards/month_end_rewards.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

const _ada = 'ada';
const _ben = 'ben';

/// 18:00 UTC is mid-morning in Vancouver, safely inside the local day.
DateTime _at(int m, int d) => DateTime.utc(2026, m, d, 18);

/// Early October: September and August are closed; July is out of reach.
final DateTime _now = _at(10, 5);

const _sep = Month(2026, 9);
const _aug = Month(2026, 8);
const _jul = Month(2026, 7);

class _Ledger {
  final List<Event> events = [];
  int _n = 0;
  String _id() => 'e${(_n++).toString().padLeft(5, '0')}';

  void adult(String id) => events.add(MemberSet(
        eventId: _id(),
        deviceId: 'd',
        userId: id,
        occurredAt: _at(1, 1),
        createdAt: _at(1, 1),
        memberId: id,
        name: id,
        role: MemberRole.adult,
        active: true,
      ));

  void category(String id, {String? owner, int limit = 50000, String? main}) =>
      events.add(BudgetSliceSet(
        eventId: _id(),
        deviceId: 'd',
        userId: owner ?? _ada,
        occurredAt: _at(1, 1),
        createdAt: _at(1, 1),
        sliceId: id,
        name: id,
        ownership:
            owner == null ? const GroupSlice() : PersonalSlice(owner),
        limitCents: limit,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
        mainCategoryId: main,
      ));

  void quest(String id, int target,
          {PartyOwnership ownership = const SharedParty(), String? main}) =>
      events.add(QuestSet(
        eventId: _id(),
        deviceId: 'd',
        userId: _ada,
        occurredAt: _at(1, 1),
        createdAt: _at(1, 1),
        questId: id,
        name: id,
        targetCents: target,
        ownership: ownership,
        mainCategoryId: main,
      ));

  void buy(String who, String slice, int cents, DateTime when) =>
      events.add(PurchaseAdded(
        eventId: _id(),
        deviceId: 'd',
        userId: who,
        occurredAt: when,
        createdAt: when,
        purchaseId: 'p$_n',
        target: SliceCharge(slice),
        amountCents: cents,
      ));

  /// [who] logs a small purchase on each of [days] days of [month].
  void logDays(String who, String slice, Month month, int days,
      {int cents = 100}) {
    for (var d = 1; d <= days; d++) {
      buy(who, slice, cents, _at(month.month, d));
    }
  }

  void allocate(String who, String slice, Month month, List<Allocation> lines,
          {DateTime? at}) =>
      events.add(LeftoverAllocated(
        eventId: _id(),
        deviceId: 'd',
        userId: who,
        occurredAt: at ?? _at(month.next().month, 2),
        createdAt: at ?? _at(month.next().month, 2),
        forUserId: who,
        month: month,
        sliceId: slice,
        allocations: lines,
      ));
}

Allocation _toQuest(String q, int cents) =>
    Allocation(destination: QuestDestination(q), amountCents: cents);

const _carry = CarryInSlice();

const _soloAda = Party([PartyAdult(_ada, inAdventure: true)]);
const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);

/// Runs the month-end rewards the way the engine does, keeping the game log.
class _Device {
  _Device({this.party = _soloAda});

  final Party party;
  final List<GameEvent> log = [];
  int _ids = 0;

  GameState get state => projectGameState(log);

  List<GameEvent> run(List<Event> ledger, {DateTime? now, bool reduced = true}) {
    final at = now ?? _now;
    final out = const LedgerMonthEndRewards().evaluate(
      ledger,
      state,
      FixedClock(at),
      party: party,
      stamp: GameEventStamp(
          deviceId: 'dev',
          newEventId: () => 'g${(_ids++).toString().padLeft(5, '0')}'),
      household: reduced ? reduce(ledger, asOf: at) : null,
    );
    log.addAll(out);
    return out;
  }
}

List<String> _chestIds(List<GameEvent> out) =>
    [for (final e in out.whereType<ChestGranted>()) e.chestId];

List<String> _rewardIds(List<GameEvent> out) =>
    [for (final e in out.whereType<RewardGranted>()) e.rewardId];

void main() {
  group('ledger inputs', () {
    test('logged days count distinct household days a person showed up', () {
      final l = _Ledger()..category('food', owner: _ada);
      l.logDays(_ada, 'food', _sep, 3);
      l.buy(_ada, 'food', 100, _at(9, 2)); // a second purchase that day
      l.buy(_ben, 'food', 100, _at(9, 5));
      l.events.add(NoSpendCheckedIn(
        eventId: 'ns',
        deviceId: 'd',
        userId: _ada,
        occurredAt: _at(9, 9),
        createdAt: _at(9, 9),
      ));
      expect(loggedDaysInMonth(l.events, _ada, _sep), 4);
      expect(loggedDaysInMonth(l.events, _ben, _sep), 1);
      expect(loggedDaysInMonth(l.events, _ada, _aug), 0);
    });

    test('savings months are those with a non-debt allocation; the latest '
        'allocation for a category and month wins', () {
      final l = _Ledger();
      l.allocate(_ada, 'food', _jul, [
        const Allocation(destination: _carry, amountCents: 500),
      ]);
      l.allocate(_ada, 'food', _aug, [
        const Allocation(destination: OverbudgetPayment('food'), amountCents: 500),
      ]);
      l.allocate(_ada, 'fun', _sep, [_toQuest('q', 100)]);
      l.allocate(_ada, 'fun', _sep, [
        const Allocation(destination: OverbudgetPayment('fun'), amountCents: 100),
      ], at: _at(10, 3));
      expect(savingsAllocationMonths(l.events, _ada), {_jul});
    });
  });

  group('gold chest', () {
    _Ledger base() => _Ledger()
      ..adult(_ada)
      ..adult(_ben)
      ..category('food', owner: _ada, limit: 50000)
      ..category('fun', owner: _ada, limit: 10000)
      ..category('home', limit: 10000);

    test('a personal category at or under its limit, in a well-logged closed '
        'month, earns the gold chest', () {
      final l = base()..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays);
      final d = _Device();
      final out = d.run(l.events);
      expect(_chestIds(out), ['${GameReasonCodes.monthGold}:$_ada:2026-09']);
      expect(out.whereType<ChestGranted>().single.chestType, ChestType.gold);
      expect(d.state.person(_ada).unopenedChests.values, [ChestType.gold]);
    });

    test('not logging is never mistaken for staying under budget', () {
      final l = base()
        ..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays - 1);
      expect(_chestIds(_Device().run(l.events)), isEmpty);
    });

    test('an overspent category earns nothing, but one under budget still '
        'does (the bonus never penalises the other)', () {
      final l = base()
        ..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays)
        ..buy(_ada, 'fun', 20000, _at(9, 20));
      expect(_chestIds(_Device().run(l.events)), hasLength(1));
      final over = base()
        ..logDays(_ada, 'fun', _sep, Balance.goldChestMinLoggedDays,
            cents: 2000);
      expect(_chestIds(_Device().run(over.events)), isEmpty);
    });

    test('group categories and the still-open month do not count', () {
      final l = base()
        ..logDays(_ada, 'home', _sep, Balance.goldChestMinLoggedDays)
        ..logDays(_ada, 'food', const Month(2026, 10), 4);
      expect(_chestIds(_Device().run(l.events)), isEmpty);
    });

    test('only months within the lookback are rewarded', () {
      final l = base()..logDays(_ada, 'food', _jul, Balance.goldChestMinLoggedDays);
      expect(_chestIds(_Device().run(l.events)), isEmpty);
      final aug = base()..logDays(_ada, 'food', _aug, Balance.goldChestMinLoggedDays);
      expect(_chestIds(_Device().run(aug.events)),
          ['${GameReasonCodes.monthGold}:$_ada:2026-08']);
    });

    test('a Standard adult gets no chest; an Adventure partner is unaffected',
        () {
      final l = base()
        ..category('ben-food', owner: _ben)
        ..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays)
        ..logDays(_ben, 'ben-food', _sep, Balance.goldChestMinLoggedDays);
      final mixed = _Device(party: const Party([
        PartyAdult(_ada, inAdventure: true),
        PartyAdult(_ben, inAdventure: false),
      ]));
      expect(_chestIds(mixed.run(l.events)),
          ['${GameReasonCodes.monthGold}:$_ada:2026-09']);
      final both = _Device(party: _duo);
      expect(_chestIds(both.run(l.events)), hasLength(2));
    });

    test('idempotent, and never clawed back by a later correction', () {
      final l = base()..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays);
      final d = _Device();
      d.run(l.events);
      expect(d.run(l.events), isEmpty);
      // A late, honest purchase now puts September over: nothing is taken.
      l.buy(_ada, 'food', 900000, _at(9, 28));
      expect(d.run(l.events), isEmpty);
      expect(d.state.person(_ada).unopenedChests, hasLength(1));
    });

    test('reduces the ledger itself when no household state is passed', () {
      final l = base()..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays);
      expect(_chestIds(_Device().run(l.events, reduced: false)), hasLength(1));
    });
  });

  group('vault: quest milestones', () {
    test('a quest crossing a share of its goal pays each milestone once', () {
      final l = _Ledger()
        ..adult(_ada)
        ..category('food', owner: _ada, limit: 10000, main: 'food')
        ..quest('canoe', 16000,
            ownership: const PersonalParty(_ada), main: 'food')
        ..allocate(_ada, 'food', _aug, [_toQuest('canoe', 8000)]);
      final hh = reduce(l.events, asOf: _now);
      expect(hh.quests['canoe']!.totalContributedCents, 8000);

      final d = _Device();
      final first = d.run(l.events);
      expect(_rewardIds(first), [
        '${GameReasonCodes.vaultQuest}:$_ada:canoe:25',
        '${GameReasonCodes.vaultQuest}:$_ada:canoe:50',
      ]);
      expect(first.whereType<RewardGranted>().map((r) => r.gems),
          [Balance.questMilestoneGems[25], Balance.questMilestoneGems[50]]);
      expect(d.run(l.events), isEmpty);

      l.allocate(_ada, 'food', _sep, [_toQuest('canoe', 8000)]);
      expect(_rewardIds(d.run(l.events)), [
        '${GameReasonCodes.vaultQuest}:$_ada:canoe:75',
        '${GameReasonCodes.vaultQuest}:$_ada:canoe:100',
      ]);
    });

    test('a shared quest rewards each Adventure adult who funded it', () {
      final l = _Ledger()
        ..adult(_ada)
        ..adult(_ben)
        ..category('food', owner: _ada, limit: 10000, main: 'food')
        ..quest('trip', 40000, main: 'food')
        ..allocate(_ada, 'food', _sep, [_toQuest('trip', 10000)]);
      final out = _Device(party: _duo).run(l.events);
      expect(_rewardIds(out), ['${GameReasonCodes.vaultQuest}:$_ada:trip:25']);
    });

    test('rewards read shares of the goal, never amounts', () {
      // The same share of a tiny goal and a huge one pays the same.
      List<int> gemsFor(int target) {
        final l = _Ledger()
          ..adult(_ada)
          ..category('food', owner: _ada, limit: target, main: 'food')
          ..quest('q', target, ownership: const PersonalParty(_ada), main: 'food')
          ..allocate(_ada, 'food', _sep, [_toQuest('q', target ~/ 2)]);
        return [
          for (final r in _Device().run(l.events).whereType<RewardGranted>())
            r.gems,
        ];
      }

      expect(gemsFor(2000), gemsFor(2000000));
    });
  });

  group('vault: savings consistency', () {
    test('consecutive closed months with a savings allocation pay at each '
        'mark, once', () {
      final l = _Ledger()..adult(_ada);
      for (final m in [_jul, _aug, _sep]) {
        l.allocate(_ada, 'food', m, [
          const Allocation(destination: _carry, amountCents: 100),
        ]);
      }
      final d = _Device();
      final out = d.run(l.events);
      expect(_rewardIds(out),
          ['${GameReasonCodes.vaultSavingsStreak}:$_ada:2026-07:3']);
      expect(out.whereType<RewardGranted>().single.gems,
          Balance.savingsStreakGems[3]);
      expect(d.run(l.events), isEmpty);
    });

    test('a gap restarts the count; an old run is not paid', () {
      final l = _Ledger()..adult(_ada);
      for (final m in [
        const Month(2026, 2),
        const Month(2026, 3),
        const Month(2026, 4),
        _aug,
        _sep,
      ]) {
        l.allocate(_ada, 'food', m, [
          const Allocation(destination: _carry, amountCents: 100),
        ]);
      }
      expect(_rewardIds(_Device().run(l.events)), isEmpty);
    });
  });

  group('wired into the reward engine', () {
    test('the engine runs month-end rewards by default', () {
      final l = _Ledger()
        ..adult(_ada)
        ..category('food', owner: _ada)
        ..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays);
      final out = const RewardEngine().evaluate(
        l.events,
        GameState.initial(),
        FixedClock(_now),
        party: _soloAda,
        stamp: GameEventStamp(deviceId: 'd', newEventId: _counter()),
        household: reduce(l.events, asOf: _now),
      );
      expect(_chestIds(out), contains('${GameReasonCodes.monthGold}:$_ada:2026-09'));
    });

    test('no game event ever changes the ledger: rewards are game events', () {
      final l = _Ledger()
        ..adult(_ada)
        ..category('food', owner: _ada)
        ..logDays(_ada, 'food', _sep, Balance.goldChestMinLoggedDays);
      final before = reduce(l.events, asOf: _now);
      final out = _Device().run(l.events);
      expect(out, everyElement(isA<GameEvent>()));
      final after = reduce(l.events, asOf: _now);
      expect(after.vaultCents, before.vaultCents);
      expect(after.warChest.balanceCents, before.warChest.balanceCents);
    });
  });
}

String Function() _counter() {
  var n = 0;
  return () => 'c${(n++).toString().padLeft(5, '0')}';
}
