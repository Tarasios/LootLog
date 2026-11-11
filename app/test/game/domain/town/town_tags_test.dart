import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/town/quest_board_view.dart';
import 'package:lootlog/game/domain/town/town_tags.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

final now = DateTime.utc(2026, 10, 3, 18);

final town = TownView.from(GameState.initial(), 'alex', const [
  TownAdult(memberId: 'alex', name: 'Alex', inAdventure: true),
  TownAdult(memberId: 'sam', name: 'Sam', inAdventure: false),
], now);

QuestBoardGoal goal(String questId, int percent) => QuestBoardGoal(
  questId: questId,
  name: questId,
  percent: percent,
  remaining: const Money(1000),
  target: const Money(2000),
  shared: true,
);

List<TownTag> tagsFor({
  QuestBoardView board = const QuestBoardView(),
  int leftoversToDivide = 0,
  List<TownBill> upcomingBills = const [],
  int unopenedChests = 0,
  Set<int> upgradeReadyPlots = const {},
  TownTagLines lines = TownTagLines.defaults,
}) => townTags(
  view: town,
  board: board,
  leftoversToDivide: leftoversToDivide,
  upcomingBills: upcomingBills,
  unopenedChests: unopenedChests,
  lines: lines,
  upgradeReadyPlots: upgradeReadyPlots,
);

TownTag? tagAt(List<TownTag> tags, TownTagAnchor anchor) {
  for (final tag in tags) {
    if (tag.anchor == anchor) return tag;
  }
  return null;
}

void main() {
  group('TownTagLines', () {
    test('missing keys fall back to the built-in lines', () {
      expect(TownTagLines.fromJson(const {}), TownTagLines.defaults);
      final edited = TownTagLines.fromJson(const {
        'toDivide': '{count} spoils await',
        'chestWaiting': 42,
      });
      expect(edited.toDivide, '{count} spoils await');
      expect(edited.chestWaiting, TownTagLines.defaults.chestWaiting);
      expect(edited.billDue, TownTagLines.defaults.billDue);
    });

    test('the shipped town_tags.json carries the built-in lines', () {
      final json =
          jsonDecode(File('assets/game/text/town_tags.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(TownTagLines.fromJson(json), TownTagLines.defaults);
      for (final key in [
        'toDivide',
        'billDue',
        'billDueToday',
        'goalProgress',
        'chestWaiting',
        'upgradeReady',
      ]) {
        expect(json[key], isA<String>(), reason: key);
      }
    });
  });

  test('nothing actionable, no tags', () {
    expect(tagsFor(), isEmpty);
  });

  test('leftovers to divide tag the gate, urgently', () {
    final tag = tagAt(tagsFor(leftoversToDivide: 3), const GateAnchor())!;
    expect(tag.text, '3 to divide');
    expect(tag.urgent, isTrue);
  });

  test("a personal bill due soon tags its owner's house", () {
    final tags = tagsFor(
      upcomingBills: const [(name: 'Phone', daysUntilDue: 2, ownerId: 'sam')],
    );
    final tag = tagAt(tags, const HouseAnchor('sam'))!;
    expect(tag.text, 'Phone in 2d');
    expect(tag.urgent, isFalse);
  });

  test('a shared bill tags the Central Hall plot', () {
    final tags = tagsFor(
      upcomingBills: const [(name: 'Rent', daysUntilDue: 0, ownerId: null)],
    );
    final tag = tagAt(tags, const PlotAnchor(0))!;
    expect(tag.text, 'Rent today');
    expect(tag.urgent, isTrue);
  });

  test('bills more than three days away are left out', () {
    expect(
      tagsFor(
        upcomingBills: const [(name: 'Rent', daysUntilDue: 4, ownerId: null)],
      ),
      isEmpty,
    );
    expect(
      tagsFor(
        upcomingBills: const [(name: 'Rent', daysUntilDue: 3, ownerId: null)],
      ),
      hasLength(1),
    );
  });

  test('a bill whose owner has no house in town goes to the Central Hall', () {
    final tags = tagsFor(
      upcomingBills: const [(name: 'Gym', daysUntilDue: 1, ownerId: 'casey')],
    );
    expect(tagAt(tags, const PlotAnchor(0))!.text, 'Gym in 1d');
  });

  test('goal progress tags the goal statue', () {
    final tags = tagsFor(board: QuestBoardView(goals: [goal('canoe', 40)]));
    expect(tagAt(tags, const StatueAnchor('canoe'))!.text, 'canoe 40%');
  });

  test(
    'goals with no progress yet get no tag; at most one per statue spot',
    () {
      final goals = [
        for (var index = 0; index < 6; index++)
          goal('goal$index', 60 - index * 10),
      ];
      final tags = tagsFor(
        board: QuestBoardView(goals: [...goals, goal('fresh', 0)]),
      );
      final statueTags = tags
          .where((tag) => tag.anchor is StatueAnchor)
          .toList();
      expect(statueTags, hasLength(town.layout.statueSpots.length));
      expect(tagAt(tags, const StatueAnchor('fresh')), isNull);
    },
  );

  test('a waiting chest and upgradable buildings get calm tags', () {
    final tags = tagsFor(unopenedChests: 2, upgradeReadyPlots: {1});
    expect(tagAt(tags, const PlotAnchor(0))!.text, 'Chest waiting');
    expect(tagAt(tags, const PlotAnchor(1))!.text, 'Ready to upgrade');
    expect(tags.every((tag) => !tag.urgent), isTrue);
  });

  test('at most one tag per anchor, the urgent one winning', () {
    final tags = tagsFor(
      unopenedChests: 1,
      upgradeReadyPlots: {0},
      upcomingBills: const [
        (name: 'Internet', daysUntilDue: 3, ownerId: null),
        (name: 'Rent', daysUntilDue: 0, ownerId: null),
      ],
    );
    final onHall = tags
        .where((tag) => tag.anchor == const PlotAnchor(0))
        .toList();
    expect(onHall, hasLength(1));
    expect(onHall.single.text, 'Rent today');
  });

  test('bills due the same day settle the shared spot by name', () {
    for (final bills in const [
      [
        (name: 'Water', daysUntilDue: 2, ownerId: null),
        (name: 'Power', daysUntilDue: 2, ownerId: null),
      ],
      [
        (name: 'Power', daysUntilDue: 2, ownerId: null),
        (name: 'Water', daysUntilDue: 2, ownerId: null),
      ],
    ]) {
      expect(
        tagAt(tagsFor(upcomingBills: bills), const PlotAnchor(0))!.text,
        'Power in 2d',
      );
    }
  });

  test('without an urgent tag the soonest bill outranks the chest', () {
    final tags = tagsFor(
      unopenedChests: 1,
      upcomingBills: const [(name: 'Internet', daysUntilDue: 3, ownerId: null)],
    );
    expect(tagAt(tags, const PlotAnchor(0))!.text, 'Internet in 3d');
  });

  test('urgent tags come first', () {
    final tags = tagsFor(
      board: QuestBoardView(goals: [goal('canoe', 40)]),
      leftoversToDivide: 1,
      unopenedChests: 1,
    );
    expect(tags.first.urgent, isTrue);
    expect(tags.first.anchor, const GateAnchor());
  });

  test('text comes from the lines given', () {
    const lines = TownTagLines(
      toDivide: '{count} spoils',
      billDue: '{name}: {days} days',
      billDueToday: '{name} is due',
      goalProgress: '{percent}% of {name}',
      chestWaiting: 'Open me',
      upgradeReady: 'Build!',
    );
    final tags = tagsFor(
      lines: lines,
      leftoversToDivide: 2,
      board: QuestBoardView(goals: [goal('canoe', 40)]),
      upcomingBills: const [
        (name: 'Phone', daysUntilDue: 2, ownerId: 'alex'),
        (name: 'Rent', daysUntilDue: 0, ownerId: 'sam'),
      ],
      unopenedChests: 1,
      upgradeReadyPlots: {2},
    );
    expect(tagAt(tags, const GateAnchor())!.text, '2 spoils');
    expect(tagAt(tags, const HouseAnchor('alex'))!.text, 'Phone: 2 days');
    expect(tagAt(tags, const HouseAnchor('sam'))!.text, 'Rent is due');
    expect(tagAt(tags, const StatueAnchor('canoe'))!.text, '40% of canoe');
    expect(tagAt(tags, const PlotAnchor(0))!.text, 'Open me');
    expect(tagAt(tags, const PlotAnchor(2))!.text, 'Build!');
  });
}
