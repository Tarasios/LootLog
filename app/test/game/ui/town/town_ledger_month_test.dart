/// The quest board follows the calendar: left open across a month end, its
/// category monsters move on to the new month's budgets on the next tick,
/// without waiting for the ledger to change.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/household_context.dart';
import 'package:lootlog/features/settings/visibility_prefs.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/decor/goal_pictures.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/quest_board.dart';
import 'package:lootlog/game/ui/town/town_home_layout.dart';

/// A clock the test moves by hand.
class _MovableClock implements Clock {
  _MovableClock(this.instant);

  DateTime instant;

  @override
  DateTime now() => instant;
}

/// Every other adult's budgets shown, with no file I/O.
class _ShowEveryone extends ShowHouseholdBudgets {
  @override
  bool build() => true;
}

DateTime _at(int month, int day) => DateTime.utc(2026, month, day, 18);

/// Alex, a $100 Food budget from May, and $40 spent on it in May.
List<Event> _mayFoodSpending() => [
      MemberSet(
        eventId: 'e01',
        deviceId: 'd',
        userId: 'alex',
        occurredAt: _at(5, 1),
        createdAt: _at(5, 1),
        memberId: 'alex',
        name: 'Alex',
        role: MemberRole.adult,
      ),
      BudgetSliceSet(
        eventId: 'e02',
        deviceId: 'd',
        userId: 'alex',
        occurredAt: _at(5, 1),
        createdAt: _at(5, 1),
        sliceId: 'food',
        name: 'Food',
        ownership: const PersonalSlice('alex'),
        limitCents: 10000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
      ),
      PurchaseAdded(
        eventId: 'e03',
        deviceId: 'd',
        userId: 'alex',
        occurredAt: _at(5, 20),
        createdAt: _at(5, 20),
        purchaseId: 'groceries',
        target: const SliceCharge('food'),
        amountCents: 4000,
      ),
    ];

void main() {
  testWidgets('the quest board moves to the new month across a month end', (
    tester,
  ) async {
    // 23:00 on May 31 in Vancouver.
    final clock = _MovableClock(DateTime.utc(2026, 6, 1, 6));
    final household = reduce(_mayFoodSpending(), asOf: _at(6, 2));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdStateProvider.overrideWith((ref) => Stream.value(household)),
          meUserIdProvider.overrideWithValue('alex'),
          userNamesProvider.overrideWithValue(const {'alex': 'Alex'}),
          showHouseholdBudgetsProvider.overrideWith(_ShowEveryone.new),
          goalPictureImagesProvider.overrideWith((ref) async => const {}),
          gameClockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          theme: AdventureTheme.build(),
          home: Scaffold(
            body: GameSpriteScope(
              tier: AdventureTier.pixel,
              registry: AssetRegistry.empty,
              child: LiveQuestBoard(onOpenGoals: () {}, onOpenLedger: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    Money foodRemaining() => tester
        .widget<QuestBoard>(find.byType(QuestBoard))
        .board
        .monsters
        .singleWhere((monster) => monster.categoryId == 'food')
        .remaining;

    expect(foodRemaining(), const Money(6000), reason: 'May: \$40 of \$100 spent');

    // 01:00 on June 1 in Vancouver; the board's ticker fires.
    clock.instant = DateTime.utc(2026, 6, 1, 8);
    await tester.pump(const Duration(seconds: 31));

    expect(foodRemaining(), const Money(10000), reason: 'June: nothing spent yet');
  });
}
