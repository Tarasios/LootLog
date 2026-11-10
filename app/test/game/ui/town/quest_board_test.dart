import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/town/quest_board_view.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/game/ui/town/quest_board.dart';

const canoe = QuestBoardGoal(
  questId: 'canoe',
  name: 'Canoe',
  percent: 40,
  remaining: Money(78000),
  target: Money(130000),
  shared: false,
);

const groceries = QuestBoardMonster(
  categoryId: 'groceries',
  name: 'Groceries',
  remaining: Money(60000),
  limit: Money(80000),
  enraged: false,
  group: true,
  colorArgb: 0xFF72B84E,
);

const fun = QuestBoardMonster(
  categoryId: 'fun',
  name: 'Fun',
  remaining: Money.zero,
  limit: Money(20000),
  enraged: true,
  group: false,
  colorArgb: 0xFFCF5E53,
  overspend: Money(1200),
);

final QuestBoardView fullBoard = QuestBoardView(
  goals: const [canoe],
  debts: const [
    QuestBoardDebt(categoryId: 'games', name: 'Games', outstanding: Money(4000)),
  ],
  pendingWrits: 2,
  monsters: const [groceries, fun],
  recent: [
    QuestBoardEntry(
      label: 'Corner Market',
      amount: const Money(3000),
      occurredAt: DateTime.utc(2026, 10, 2),
    ),
  ],
);

Future<void> pumpBoard(
  WidgetTester tester,
  QuestBoardView board, {
  VoidCallback? onOpenGoals,
  VoidCallback? onOpenLedger,
  VoidCallback? onCollapse,
}) async {
  tester.view.physicalSize = const Size(340, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AdventureTheme.build(),
      home: Scaffold(
        body: GameSpriteScope(
          tier: AdventureTier.pixel,
          registry: AssetRegistry.empty,
          child: QuestBoard(
            board: board,
            onOpenGoals: onOpenGoals ?? () {},
            onOpenLedger: onOpenLedger ?? () {},
            onCollapse: onCollapse,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows every section of a busy board', (tester) async {
    await pumpBoard(tester, fullBoard);
    expect(find.text('Quest board'), findsOneWidget);
    expect(find.text('Canoe'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text(r'$780.00 to go'), findsOneWidget);
    expect(find.text('Games'), findsOneWidget);
    expect(find.text(r'$40.00 to clear'), findsOneWidget);
    expect(find.text('Writs to sign: 2'), findsOneWidget);
    expect(find.text(r'$600.00 left'), findsOneWidget);
    expect(find.text(r'enraged · $12.00 over'), findsOneWidget);
    expect(find.text('Corner Market'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the HP bars show what is left of each limit', (tester) async {
    await pumpBoard(tester, fullBoard);
    final meters = tester.widgetList<MeterBar>(find.byType(MeterBar)).toList();
    // The goal, then Groceries (calm) and Fun (enraged).
    expect(meters.map((meter) => meter.fraction), [0.4, 0.75, 0.0]);
    expect(meters.map((meter) => meter.color), [
      AdventureTokens.hpGreen,
      AdventureTokens.hpGreen,
      AdventureTokens.hpRed,
    ]);
  });

  testWidgets('no debts and no writs leave those sections out', (tester) async {
    await pumpBoard(tester, const QuestBoardView(goals: [canoe]));
    expect(find.text('OVERBUDGET'), findsNothing);
    expect(find.textContaining('Writs to sign'), findsNothing);
  });

  testWidgets('an empty board invites a first goal', (tester) async {
    var goalsOpened = 0;
    await pumpBoard(
      tester,
      const QuestBoardView(),
      onOpenGoals: () => goalsOpened++,
    );
    await tester.tap(find.textContaining('Set a savings goal'));
    expect(goalsOpened, 1);
  });

  testWidgets('a goal opens the goals; a monster opens the ledger', (
    tester,
  ) async {
    var goalsOpened = 0;
    var ledgerOpened = 0;
    await pumpBoard(
      tester,
      fullBoard,
      onOpenGoals: () => goalsOpened++,
      onOpenLedger: () => ledgerOpened++,
    );
    await tester.tap(find.text('Canoe'));
    expect(goalsOpened, 1);
    await tester.tap(find.text('Groceries'));
    expect(ledgerOpened, 1);
  });

  testWidgets('the chevron folds the board away', (tester) async {
    var collapsed = 0;
    await pumpBoard(tester, fullBoard, onCollapse: () => collapsed++);
    await tester.tap(find.byKey(const ValueKey('quest-board-collapse')));
    expect(collapsed, 1);
  });
}
