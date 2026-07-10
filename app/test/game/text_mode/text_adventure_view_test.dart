import 'package:lootlog/game/adapter.dart';
import 'package:lootlog/game/game_state.dart';
import 'package:lootlog/game/text_mode/text_adventure_view.dart';
import 'package:lootlog/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../adventure_fixtures.dart';

GameState _withRoster(GameState g) => GameState(
      currentMonth: g.currentMonth,
      floorNumber: g.floorNumber,
      heroName: g.heroName,
      heroSprite: g.heroSprite,
      partnerSprite: g.partnerSprite,
      heroHpLostCents: g.heroHpLostCents,
      expeditionSuppliesCents: g.expeditionSuppliesCents,
      monsters: g.monsters,
      contracts: g.contracts,
      party: g.party,
      questMonsters: g.questMonsters,
      provisioning: g.provisioning,
      goldPouch: g.goldPouch,
      warChest: g.warChest,
      reserveCaches: g.reserveCaches,
      expeditions: g.expeditions,
      roster: [
        Adventurer(
          memberId: 'u1',
          name: 'Robin',
          role: AdventurerRole.adventurer,
          descriptionText: 'A steady hand with a ledger.',
          isMe: true,
          sprite: SpriteRef.asset(Sprites.heroA, label: 'Robin'),
        ),
        Adventurer(
          memberId: 'mochi',
          name: 'Mochi',
          role: AdventurerRole.familiar,
          isMe: false,
          sprite: SpriteRef.asset(Sprites.pet, label: 'Mochi'),
        ),
      ],
    );

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  final log = [
    LogEntry(
      id: 'e1',
      line: r'GROCERIES MONSTER TAKES $42.00 DMG',
      tone: LogTone.strike,
      occurredAt: DateTime.utc(2026, 7, 3),
      isMine: true,
    ),
    LogEntry(
      id: 'e2',
      line: r'TREASURE FOUND — $50.00 for Robin',
      tone: LogTone.treasure,
      occurredAt: DateTime.utc(2026, 7, 4),
      isMine: true,
    ),
  ];

  testWidgets('renders the floor, roster, quests, treasury and log', (t) async {
    await t.pumpWidget(_wrap(TextAdventureView(
      game: _withRoster(sampleGameState()),
      log: log,
    )));

    // The two prime actions and the always-visible Classic toggle.
    expect(find.text('Strike a monster'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);

    // Party roster with the user-written description.
    expect(find.text('A steady hand with a ledger.'), findsOneWidget);

    // A monster, a quest boss, and the treasury.
    expect(find.text('Food'), findsWidgets);
    expect(find.text('Canoe'), findsOneWidget);
    expect(find.textContaining('Gold pouch'), findsOneWidget);

    // The adventure log, in game voice.
    expect(find.text(r'GROCERIES MONSTER TAKES $42.00 DMG'), findsOneWidget);
  });

  testWidgets('Strike a monster and Classic fire their callbacks', (t) async {
    var struck = 0;
    var classic = 0;
    await t.pumpWidget(_wrap(TextAdventureView(
      game: _withRoster(sampleGameState()),
      log: log,
      callbacks: TextAdventureCallbacks(
        onStrikeMonster: () => struck++,
        onSwitchToClassic: () => classic++,
      ),
    )));

    await t.tap(find.text('Strike a monster'));
    await t.tap(find.text('Classic'));
    expect(struck, 1);
    expect(classic, 1);
  });

  testWidgets('a wounded party shows the encouragement line', (t) async {
    await t.pumpWidget(_wrap(TextAdventureView(
      game: _withRoster(sampleGameState()),
      log: log,
      encouragement: 'Every hero has an off day. Onward.',
    )));
    expect(find.text('Every hero has an off day. Onward.'), findsOneWidget);
  });
}
