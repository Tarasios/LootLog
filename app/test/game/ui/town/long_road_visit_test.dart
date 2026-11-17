/// Visiting a neighbour's town down the long road is read-only: their civic
/// quarters and Castle Hill open, but a plot shows only a note (never the
/// civic sheet or the workshop), the Castle opens nothing, and the visit
/// writes nothing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/town/castle_sheet.dart';
import 'package:lootlog/game/ui/town/civic_plot_sheet.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';
import 'package:lootlog/game/ui/town/workshop_panel.dart';

import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart';
import 'town_test_overrides.dart';

DateTime _ago(int days) => before(Duration(days: days));

/// Robin and Sam are neighbours; Sam's town is a city with every quarter,
/// a workshop with a job and a Castle stage rising.
List<GameEvent> _events() => [
      partyJoined('p01', kHouseholdPartyId, when: _ago(90)),
      partyJoined('p02', kHouseholdPartyId, when: _ago(90), actor: sam),
      townsSplit('p03', robin, when: _ago(90)),
      for (final tier in TownTier.values.skip(1)) tierReached('sam-${tier.name}', tier, when: _ago(80), actor: sam),
      for (final district in kDistricts)
        if (district.purchasable && district.id != kOutpostDistrictId)
          districtPurchased('sam-${district.id}', district.id, when: _ago(70), actor: sam),
      civicBuilt('sam-workshop', kMarketRowDistrictId, 0, CivicBuildingType.workshop, when: _ago(60), actor: sam),
      civicBuilt('sam-cottage', kResidentialDistrictId, 0, CivicBuildingType.cottage, when: _ago(60), actor: sam),
      refiningStarted('sam-job', 0, 'planks', when: _ago(1), completesAt: _ago(1).add(const Duration(minutes: 30)), actor: sam),
      castleStageStarted('sam-castle', 1, when: _ago(3), actor: sam),
    ];

Widget _host(InMemoryGameEventStore store) => ProviderScope(
      overrides: townTestOverrides(
        tier: AdventureTier.pixel,
        liveStore: store,
        view: const HallLedgerView(
          meId: robin,
          adults: [
            HallAdult(memberId: robin, name: 'Robin', inAdventure: true),
            HallAdult(memberId: sam, name: 'Sam', inAdventure: true),
          ],
          habitsAvailable: true,
        ),
      ),
      child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
    );

Future<void> _frames(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TownSceneView _scene(WidgetTester tester) => tester.widget<TownSceneView>(find.byType(TownSceneView).last);

void main() {
  testWidgets('a neighbour\'s quarters, workshop and Castle are read-only', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = await storeWith(_events());
    await tester.pumpWidget(_host(store));
    await _frames(tester);
    final written = (await store.all()).length;
    _scene(tester).onTarget(const SignpostTarget());
    await _frames(tester);
    expect(find.text('Visiting Sam'), findsOneWidget);
    expect(find.byKey(const ValueKey('district-map')), findsNothing, reason: 'nothing is for sale on a visit');

    for (final id in [kGuardPostDistrictId, kResidentialDistrictId, kParkDistrictId, kMarketRowDistrictId]) {
      final button = find.byKey(ValueKey('district-$id'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await _frames(tester);
      expect(_scene(tester).view.districtId, id);
      final scene = _scene(tester);
      scene.onTarget(scene.view.targetAt(scene.view.plots.first.origin)!);
      await _frames(tester);
      expect(find.byType(CivicPlotSheet), findsNothing, reason: id);
      expect(find.byType(WorkshopPanel), findsNothing, reason: id);
      expect(find.byKey(const ValueKey('neighbour-plot-info')), findsOneWidget, reason: id);
      await tester.tap(find.byKey(const ValueKey('neighbour-plot-close')));
      await _frames(tester);
    }

    final hill = find.byKey(const ValueKey('district-castleHill'));
    await tester.ensureVisible(hill);
    await tester.tap(hill);
    await _frames(tester);
    final scene = _scene(tester);
    expect(scene.view.districtId, kCastleHillDistrictId);
    expect(scene.view.castleUnderConstruction, isTrue, reason: 'Sam\'s Castle, not Robin\'s');
    scene.onTarget(scene.view.targetAt(scene.view.layout.castleOrigin!)!);
    await _frames(tester);
    expect(find.byType(CastleSheet), findsNothing);
    expect((await store.all()).length, written, reason: 'visiting writes nothing');
  });
}
