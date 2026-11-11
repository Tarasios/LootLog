/// The neighbour view on a phone: the signpost to a neighbour's town, a
/// read-only visit, a gift that moves once and fits their storehouse, one
/// cheer a day, a Standard adult's caravan camp with no visit, and the
/// cheers waiting in the neighbour's inbox.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/town/town_scene_view.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/building_sheet.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/town/gift_dialog.dart';
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../hall_harness.dart';
import 'town_test_overrides.dart';

const Size _phone = Size(390, 844);
const Size _smallPhone = Size(360, 780);

/// Robin (this device) and Sam are Adventure neighbours with their own
/// towns; Robin holds 100 lumber and 60 stone.
List<GameEvent> _neighbourEvents({int samLumber = 0}) => [
  partyJoined('p01', kHouseholdPartyId, when: before(const Duration(days: 3))),
  partyJoined('p02', kHouseholdPartyId, when: before(const Duration(days: 3)), actor: sam),
  townsSplit('p03', robin, when: before(const Duration(days: 3))),
  granted('p04',
      when: before(const Duration(days: 2)),
      materials: MaterialBundle({MaterialKind.lumber: 100, MaterialKind.stone: 60})),
  claimed('p05', 'reward-p04', when: before(const Duration(days: 2))),
  if (samLumber > 0) ...[
    granted('p06', when: before(const Duration(days: 2)), actor: sam, materials: MaterialBundle({MaterialKind.lumber: samLumber})),
    claimed('p07', 'reward-p06', when: before(const Duration(days: 2)), actor: sam),
  ],
];

HallLedgerView _view({bool samInAdventure = true, bool alone = false, String me = robin}) => HallLedgerView(
  meId: me,
  adults: [
    const HallAdult(memberId: robin, name: 'Robin', inAdventure: true),
    if (!alone) HallAdult(memberId: sam, name: 'Sam', inAdventure: samInAdventure),
  ],
  habitsAvailable: true,
);

Widget _host(InMemoryGameEventStore store, {HallLedgerView? view, AdventureTier tier = AdventureTier.pixel}) =>
    ProviderScope(
      overrides: townTestOverrides(tier: tier, liveStore: store, view: view ?? _view()),
      child: MaterialApp(home: TownShell(onOpenLedger: () {}, ambientLife: false)),
    );

Future<void> _pump(WidgetTester tester, Widget host, {Size size = _phone}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(host);
  await tester.pump();
  await _pumpUi(tester);
}

/// The Flame scene ticks forever: advance in steps instead of settling.
Future<void> _pumpUi(WidgetTester tester) async {
  for (var step = 0; step < 6; step++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

TownSceneView _scene(WidgetTester tester) => tester.widget<TownSceneView>(find.byType(TownSceneView).last);

Future<void> _tapTarget(WidgetTester tester, TownTarget target) async {
  _scene(tester).onTarget(target);
  await _pumpUi(tester);
}

Future<void> _visitSam(WidgetTester tester) async {
  await _tapTarget(tester, const SignpostTarget());
  expect(find.text('Visiting Sam'), findsOneWidget);
}

Future<List<T>> _events<T>(InMemoryGameEventStore store) async => (await store.all()).whereType<T>().toList();

void main() {
  testWidgets('alone: no signpost, nothing to explain', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store, view: _view(alone: true)));
    expect(_scene(tester).view.showsSignpost, isFalse);
    expect(_scene(tester).view.showsCaravanCamp, isFalse);
    expect(find.textContaining('neighbour'), findsNothing);
  });

  testWidgets('the signpost opens the neighbour\'s town read-only', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store));
    expect(_scene(tester).view.showsSignpost, isTrue);
    final before = (await store.all()).length;
    await _visitSam(tester);
    // Sam's own town: the starter plots, nothing of Robin's.
    expect(_scene(tester).view.plots.where((plot) => plot.unlocked), hasLength(Balance.startingPlotCount));
    expect(find.textContaining('Log purchase'), findsOneWidget);
    expect(find.byKey(const ValueKey('neighbour-gift')), findsOneWidget);
    expect(find.byKey(const ValueKey('neighbour-cheer')), findsOneWidget);
    // Plots and houses only open read-only notes; no command can run.
    await _tapTarget(tester, const PlotTarget(0));
    expect(find.byType(BuildingSheet), findsNothing);
    expect(find.byKey(const ValueKey('neighbour-plot-info')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('neighbour-plot-close')));
    await _pumpUi(tester);
    await _tapTarget(tester, const GateTarget());
    await _tapTarget(tester, const HouseTarget(sam));
    expect((await store.all()).length, before, reason: 'visiting writes nothing');
    // Back home.
    await tester.tap(find.byKey(const ValueKey('neighbour-back')));
    await _pumpUi(tester);
    expect(find.text('Visiting Sam'), findsNothing);
    expect(_scene(tester).view.showsSignpost, isTrue);
  });

  testWidgets('a gift moves the chosen materials once and fits their storehouse', (tester) async {
    final cap = Balance.storehouseCapacityByTier[0];
    final store = await storeWith(_neighbourEvents(samLumber: cap - 30));
    await _pump(tester, _host(store));
    await _visitSam(tester);
    await tester.tap(find.byKey(const ValueKey('neighbour-gift')));
    await _pumpUi(tester);
    expect(find.byType(GiftDialog), findsOneWidget);
    // Lumber: Sam has room for 30, so the stepper stops there.
    final addLumber = find.byKey(const ValueKey('gift-more-lumber'));
    for (var tap = 0; tap < 5; tap++) {
      await tester.ensureVisible(addLumber);
      await tester.tap(addLumber);
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('gift-amount-lumber'))).data, '30');
    await tester.tap(find.byKey(const ValueKey('gift-more-stone')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const ValueKey('gift-amount-stone'))).data, '10');
    await tester.tap(find.byKey(const ValueKey('gift-send')));
    await _pumpUi(tester);
    final gifts = await _events<GiftSent>(store);
    expect(gifts, hasLength(1));
    expect(gifts.single.toPersonId, sam);
    expect(gifts.single.bundle, MaterialBundle({MaterialKind.lumber: 30, MaterialKind.stone: 10}));
    expect(find.textContaining("Sent 30 lumber"), findsOneWidget);
    expect(find.byType(GiftDialog), findsNothing);
  });

  testWidgets('one cheer a day', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store));
    await _visitSam(tester);
    await tester.tap(find.byKey(const ValueKey('neighbour-cheer')));
    await _pumpUi(tester);
    expect(await _events<CheerSent>(store), hasLength(1));
    expect(find.textContaining("You cheered Sam's town"), findsOneWidget);
    expect(find.textContaining('Cheered today'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('neighbour-cheer')));
    await _pumpUi(tester);
    expect(await _events<CheerSent>(store), hasLength(1));
  });

  testWidgets('a Standard neighbour is a caravan camp with no visit', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store, view: _view(samInAdventure: false)));
    expect(_scene(tester).view.showsCaravanCamp, isTrue);
    expect(_scene(tester).view.showsSignpost, isFalse);
    expect(find.text('Visiting Sam'), findsNothing);
  });

  testWidgets('the neighbour sees the cheer in their inbox', (tester) async {
    final store = await storeWith([
      ..._neighbourEvents(),
      CheerSent(
        eventId: 'p09',
        deviceId: 'phone-robin',
        actorId: robin,
        occurredAt: before(const Duration(hours: 2)),
        createdAt: before(const Duration(hours: 2)),
        toPersonId: sam,
        day: GameDay.fromInstant(before(const Duration(hours: 2))),
      ),
    ]);
    await _pump(tester, _host(store, view: _view(me: sam)));
    await tester.tap(find.text('Inbox'));
    await _pumpUi(tester);
    expect(find.text('Robin cheered your town'), findsOneWidget);
  });

  testWidgets('the text tier visits, gifts and cheers as plain sections', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store, tier: AdventureTier.text));
    await tester.scrollUntilVisible(find.byKey(const ValueKey('text-neighbour-cheer-$sam')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('NEIGHBOURING TOWNS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('text-neighbour-cheer-$sam')));
    await _pumpUi(tester);
    expect(await _events<CheerSent>(store), hasLength(1));
    await tester.ensureVisible(find.byKey(const ValueKey('text-neighbour-gift-$sam')));
    await tester.tap(find.byKey(const ValueKey('text-neighbour-gift-$sam')));
    await _pumpUi(tester);
    expect(find.byType(GiftDialog), findsOneWidget);
  });

  testWidgets('a visit and the gift dialog fit a small phone', (tester) async {
    final store = await storeWith(_neighbourEvents());
    await _pump(tester, _host(store), size: _smallPhone);
    await _visitSam(tester);
    expect(tester.takeException(), isNull);
    final back = tester.getRect(find.byKey(const ValueKey('neighbour-back')));
    final log = tester.getRect(find.textContaining('Log purchase'));
    expect(back.top, greaterThanOrEqualTo(0));
    expect(log.bottom, lessThanOrEqualTo(_smallPhone.height));
    await tester.tap(find.byKey(const ValueKey('neighbour-gift')));
    await _pumpUi(tester);
    expect(tester.takeException(), isNull);
  });
}
