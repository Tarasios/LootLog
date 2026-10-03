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
import 'package:lootlog/game/ui/game_home.dart';

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

Future<void> pumpGate(WidgetTester tester, PlayPrefs? prefs) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [playPrefsProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      home: HomeGate(
        ledgerBuilder: (onOpenHall) => _FakeLedger(onOpenHall: onOpenHall),
      ),
    ),
  ));
  // A spinner never settles, so pump a frame rather than settling.
  await tester.pump();
  if (prefs != null) await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a loading screen, not the ledger or hall, until the '
      "person's mode is known", (tester) async {
    await pumpGate(tester, null);

    expect(find.byType(LoadingScreen), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);
    expect(find.byType(GameHome), findsNothing);
  });

  testWidgets('Standard launches the ledger and builds no guild hall',
      (tester) async {
    await pumpGate(tester,
        const PlayPrefs(mode: PlayMode.standard, home: AdventureHome.hall));

    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);
    expect(find.byTooltip('Guild hall'), findsNothing,
        reason: 'Standard users see the app exactly as before');
  });

  testWidgets('Adventure + Hall launches GameHome, which opens the ledger',
      (tester) async {
    await pumpGate(tester,
        const PlayPrefs(mode: PlayMode.adventure, home: AdventureHome.hall));

    expect(find.byType(GameHome), findsOneWidget);
    expect(find.text('Guild hall coming soon'), findsOneWidget);
    expect(find.text('LEDGER'), findsNothing);

    await tester.tap(find.text('Open the ledger'));
    await tester.pumpAndSettle();
    expect(find.text('LEDGER'), findsOneWidget);

    // The ledger's hall button returns to the hall rather than stacking.
    await tester.tap(find.byTooltip('Guild hall'));
    await tester.pumpAndSettle();
    expect(find.text('Guild hall coming soon'), findsOneWidget);
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
    expect(find.text('Guild hall coming soon'), findsOneWidget);

    await tester.tap(find.text('Open the ledger'));
    await tester.pumpAndSettle();
    expect(find.text('LEDGER'), findsOneWidget);
    expect(find.byType(GameHome), findsNothing);
  });
}
