/// Where the month-end ritual opens: the plain sheet in Standard mode, the
/// month-end dungeon in Adventure mode (from the dashboard banner and from
/// the hall's "divide leftovers" link alike).
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/features/household_context.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/shell/home_gate.dart';
import 'package:lootlog/features/spoils/spoils_screen.dart';
import 'package:lootlog/features/spoils/spoils_sheet.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_screen.dart';

import '../../game/ui/town/town_test_overrides.dart';
import 'spoils_fixtures.dart';

Future<void> pumpOpener(
  WidgetTester tester, {
  required bool adventure,
  required void Function(BuildContext context, WidgetRef ref) onOpen,
}) async {
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final (household, _) = ritualFixture();
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final harness = await TownTestHarness.create();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      ...harness.overrides(tier: AdventureTier.pixel),
      isAdventureProvider.overrideWithValue(adventure),
      householdStateProvider.overrideWith((ref) => Stream.value(household)),
      meUserIdProvider.overrideWithValue('alex'),
      userNamesProvider.overrideWithValue(const {'alex': 'Alex'}),
      householdActionsProvider.overrideWithValue(HouseholdActions(
        db: db,
        blobs: BlobStore(Directory.systemTemp.createTempSync('lootlog_spoils')),
        deviceId: 'test',
        meUserId: 'alex',
      )),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) {
          // Keep the household loaded, as the dashboard does.
          ref.watch(householdStateProvider);
          return Scaffold(
            body: TextButton(onPressed: () => onOpen(context, ref), child: const Text('open')),
          );
        },
      ),
    ),
  ));
  await tester.pump();
  await tester.tap(find.text('open'));
  for (var step = 0; step < 8; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('Standard: the dashboard banner opens the plain sheet', (tester) async {
    await pumpOpener(
      tester,
      adventure: false,
      onOpen: (context, ref) => openSpoilsRitual(context, ref, asOf: ritualInstant),
    );
    expect(find.byType(SpoilsSheetView), findsOneWidget);
    expect(find.byType(DungeonScreen), findsNothing);
  });

  testWidgets('Adventure: the dashboard banner opens the month-end dungeon', (tester) async {
    await pumpOpener(
      tester,
      adventure: true,
      onOpen: (context, ref) => openSpoilsRitual(context, ref, asOf: ritualInstant),
    );
    expect(find.byType(DungeonScreen), findsOneWidget);
    expect(find.byType(SpoilsSheetView), findsNothing);
  });

  testWidgets("the hall's divide-leftovers link opens the month-end dungeon", (tester) async {
    await pumpOpener(
      tester,
      adventure: true,
      onOpen: (context, ref) => ledgerHallLinks(() {}).divideLeftovers!(context, const Month(2026, 9)),
    );
    expect(find.byType(DungeonScreen), findsOneWidget);
    expect(find.byType(SpoilsSheetView), findsNothing);
  });
}
