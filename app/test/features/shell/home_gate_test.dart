/// The launch gate: Standard opens the ledger and never builds the guild hall;
/// Adventure opens the hall or the ledger per the Home setting, with a way
/// across in each direction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/settings/play_mode.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';
import 'package:lootlog/features/shell/home_gate.dart';
import 'package:lootlog/features/shell/loading_screen.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';
import 'package:lootlog/game/ui/town/town_townsfolk.dart';

import '../../game/ui/hall_harness.dart' show hallOverrides;

/// Stands in for the real AppShell (which needs the whole data layer) and
/// exposes the hall entry point the gate hands it.
class _FakeLedger extends StatelessWidget {
  const _FakeLedger({this.onOpenHall});
  final VoidCallback? onOpenHall;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('LEDGER'),
          actions: [
            if (onOpenHall != null)
              IconButton(
                tooltip: 'Guild hall',
                icon: const Icon(Icons.castle),
                onPressed: onOpenHall,
              ),
          ],
        ),
      );
}

Future<void> pumpGate(
  WidgetTester tester,
  PlayPrefs? prefs, {
  AdventureTier tier = AdventureTier.text,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      playPrefsProvider.overrideWithValue(prefs),
      // The hall over an empty in-memory game log, no database needed.
      ...hallOverrides(store: InMemoryGameEventStore(), tier: tier),
      townsfolkProvider.overrideWithValue(const []),
    ],
    child: MaterialApp(
      home: HomeGate(
        ledgerBuilder: (onOpenHall) => _FakeLedger(onOpenHall: onOpenHall),
      ),
    ),
  ));
  // A spinner never settles (nor does the town scene), so pump frames.
  await tester.pump();
  if (prefs == null) return;
  if (tier == AdventureTier.pixel) {
    await tester.pump(const Duration(milliseconds: 200));
  } else {
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('shows a loading screen, not the ledger or hall, until the '
      "person's mode is known", (tester) async {
    await pumpGate(tester, null);

    expect(find.byType(LoadingScreen), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);
    expect(find.byType(TownShell), findsNothing);
    expect(find.byType(GameHome), findsNothing);
  });

  testWidgets('Standard launches the ledger and builds no guild hall',
      (tester) async {
    await pumpGate(tester,
        const PlayPrefs(mode: PlayMode.standard, home: AdventureHome.hall));

    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.byType(TownShell), findsNothing);
    expect(find.byType(GameHome), findsNothing);
    expect(find.byTooltip('Guild hall'), findsNothing,
        reason: 'Standard users see the app exactly as before');
  });

  testWidgets('Adventure + Hall in pixel tier launches the town scene',
      (tester) async {
    await pumpGate(
        tester,
        const PlayPrefs(mode: PlayMode.adventure, home: AdventureHome.hall),
        tier: AdventureTier.pixel);

    expect(find.byType(TownShell), findsOneWidget);
    expect(find.byKey(const ValueKey('town-scene')), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);
    expect(find.text('Log a purchase'), findsOneWidget);

    await tester.tap(find.text('Budget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('LEDGER'), findsOneWidget);
  });

  testWidgets(
      'Adventure + Hall launches the town, whose text tier is the guild '
      'hall, which opens the ledger', (tester) async {
    await pumpGate(tester,
        const PlayPrefs(mode: PlayMode.adventure, home: AdventureHome.hall));

    expect(find.byType(TownShell), findsOneWidget);
    expect(find.byType(GameHome), findsOneWidget);
    expect(find.text('Log a purchase'), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('LEDGER'), findsOneWidget);

    // The ledger's hall button returns to the hall rather than stacking.
    await tester.tap(find.byTooltip('Guild hall'));
    await tester.pumpAndSettle();
    expect(find.byType(GameHome), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);
  });

  testWidgets('Adventure + Ledger launches the ledger with a way into the hall',
      (tester) async {
    await pumpGate(tester,
        const PlayPrefs(mode: PlayMode.adventure, home: AdventureHome.ledger));

    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);

    await tester.tap(find.byTooltip('Guild hall'));
    await tester.pumpAndSettle();
    expect(find.byType(TownShell), findsOneWidget);
    expect(find.byType(GameHome), findsOneWidget);

    await tester.tap(find.text('Ledger'));
    await tester.pumpAndSettle();
    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);
  });
}
