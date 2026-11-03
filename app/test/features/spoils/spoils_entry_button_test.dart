/// The "Divide leftovers" button sits in the shell's app bar, where actions are
/// laid out with unbounded width. The app theme gives filled buttons a
/// full-width minimum size, so the button must opt out of it or the whole
/// toolbar (Manage, the play-mode menu) fails layout and paints blank.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/features/household_context.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/spoils/spoils_screen.dart';
import 'package:lootlog/ui/theme.dart';

import 'spoils_fixtures.dart';

void main() {
  testWidgets('lays out inside app bar actions under the app theme',
      (tester) async {
    final ledger = TestLedger()
      ..adult('alex')
      ..category('clothing', owner: 'alex', limitCents: 2000)
      // A grace window longer than any month keeps last month's leftovers
      // waiting whatever day the test runs on.
      ..setting('spoilsGraceDays', 40);
    final household = reduce(ledger.events, asOf: DateTime.now().toUtc());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          householdStateProvider.overrideWith((ref) => Stream.value(household)),
          meUserIdProvider.overrideWithValue('alex'),
          userNamesProvider.overrideWithValue(const {'alex': 'Alex'}),
          isAdventureProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('LootLog'),
              actions: [
                const SpoilsEntryButton(),
                IconButton(
                  tooltip: 'Manage',
                  onPressed: () {},
                  icon: const Icon(Icons.menu),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Divide leftovers'), findsOneWidget);
    expect(find.byTooltip('Manage'), findsOneWidget);
  });
}
