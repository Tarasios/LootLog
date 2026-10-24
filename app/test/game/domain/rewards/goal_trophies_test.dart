import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/rewards/goal_trophies.dart';
import 'package:lootlog/game/domain/rewards/month_end_rewards.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

import '../../../features/spoils/spoils_fixtures.dart';

/// "Now" is 5 October 2026; with the two-month lookback the window starts on
/// 1 August 2026.
final DateTime nowInstant = dayOf(2026, 10, 5);
final DateTime windowStart = DateTime.utc(2026, 8, 1);
const adventureParty = Party([PartyAdult('alex', inAdventure: true), PartyAdult('sam', inAdventure: true)]);

Allocation toGoal(String questId, int cents) => Allocation(destination: QuestDestination(questId), amountCents: cents);

TestLedger baseLedger() => TestLedger()
  ..adult('alex')
  ..adult('sam')
  ..category('fun', owner: 'alex', mainCategoryId: 'entertainment');

List<GameEvent> evaluate(TestLedger ledger, {GameState? state, Party party = adventureParty}) =>
    const GoalTrophies().evaluate(
      ledger: ledger.events,
      now: reduce(ledger.events, asOf: nowInstant),
      atWindowStart: reduce([for (final event in ledger.events) if (event.occurredAt.isBefore(windowStart)) event],
          asOf: windowStart),
      state: state ?? GameState.initial(),
      party: party,
      clock: FixedClock(nowInstant),
      stamp: GameEventStamp(deviceId: 'd'),
    );

void main() {
  test('a goal finished over two rituals earns its custom trophy for its owner', () {
    final ledger = baseLedger()
      ..quest('canoe', 10000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 8), [toGoal('canoe', 5000)])
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('canoe', 5000)]);
    final trophy = evaluate(ledger).cast<ItemAcquired>().single;
    expect(trophy.itemId, trophyItemId('canoe'));
    expect(trophy.actorId, 'alex');
    expect(trophy.acquisitionId, 'trophy:canoe');
    expect(trophy.source, DecorSource.trophy);
    expect(trophy.toTown, isFalse);
  });

  test('a goal finished in a single ritual earns the plain trophy', () {
    final ledger = baseLedger()
      ..quest('jacket', 5000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('jacket', 5000)]);
    expect((evaluate(ledger).single as ItemAcquired).itemId, 'trophy_cup');
  });

  test('a shared goal becomes a statue in the town pool', () {
    final ledger = baseLedger()
      ..quest('house', 10000, mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 8), [toGoal('house', 5000)])
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('house', 5000)]);
    final statue = evaluate(ledger).single as ItemAcquired;
    expect(statue.itemId, statueItemId('house'));
    expect(statue.toTown, isTrue);
    expect(statue.actorId, 'alex', reason: 'the first Adventure adult by id holds the town grant');
  });

  test('a goal completed before the window earns nothing', () {
    final ledger = baseLedger()
      ..quest('old', 5000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2025, 3), [toGoal('old', 5000)]);
    expect(evaluate(ledger), isEmpty);
  });

  test('an already granted trophy is not granted again', () {
    final ledger = baseLedger()
      ..quest('canoe', 10000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 8), [toGoal('canoe', 5000)])
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('canoe', 5000)]);
    final granted = projectGameState(evaluate(ledger));
    expect(evaluate(ledger, state: granted), isEmpty);
  });

  test('a Standard-mode owner earns nothing (only Adventure adults earn)', () {
    final ledger = baseLedger()
      ..quest('canoe', 10000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('canoe', 10000)]);
    const standardAlex = Party([PartyAdult('alex', inAdventure: false), PartyAdult('sam', inAdventure: true)]);
    expect(evaluate(ledger, party: standardAlex), isEmpty);
  });

  test('the month-end rewards hand out the keepsake along with the other rewards', () {
    final ledger = baseLedger()
      ..quest('jacket', 5000, ownership: const PersonalParty('alex'), mainCategoryId: 'entertainment')
      ..allocate('alex', 'fun', const Month(2026, 9), [toGoal('jacket', 5000)]);
    final granted = const LedgerMonthEndRewards().evaluate(
      ledger.events,
      GameState.initial(),
      FixedClock(nowInstant),
      party: adventureParty,
      stamp: GameEventStamp(deviceId: 'd'),
    );
    expect(granted.whereType<ItemAcquired>().map((item) => item.acquisitionId), ['trophy:jacket']);
  });
}
