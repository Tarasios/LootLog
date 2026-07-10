import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/features/setup/setup_screen.dart';

void main() {
  testWidgets('a failing finish shows an error instead of doing nothing',
      (tester) async {
    // A closed database makes every DB call throw — the same shape of failure
    // Android users hit when sqlite could not load. Drift treats a close
    // before first use as a no-op, so touch the database before closing it.
    final db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    await db.close();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
        ],
        child: const MaterialApp(
          home: SetupScreen(debugJumpToSummary: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Begin the adventure'));
    await tester.pumpAndSettle();

    // The screen is still up and a visible error is shown.
    expect(find.textContaining('Could not save'), findsOneWidget);
  });

  testWidgets('a database failure during finish shows an error',
      (tester) async {
    // A closed database makes appendEvents throw — the motivating bug: sqlite
    // failing on the actual write. Drive the real wizard so buildInput()
    // succeeds and the finish path reaches the database. Drift treats a close
    // before first use as a no-op, so touch the database before closing it.
    final db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get();
    await db.close();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          deviceIdProvider.overrideWithValue('test-device'),
        ],
        child: const MaterialApp(
          home: SetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Welcome gate -> party step.
    await tester.tap(find.text('Start a new party'));
    await tester.pumpAndSettle();

    // Add one adult; the controller makes the first adult "me" automatically.
    await tester.tap(find.text('Add adult'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alex');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Advance through the remaining steps to the summary.
    while (find.text('Next').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Begin the adventure'));
    await tester.pumpAndSettle();

    // The write itself failed — the error is shown and the wizard stays up.
    expect(find.textContaining('Could not save'), findsOneWidget);
  });
}
