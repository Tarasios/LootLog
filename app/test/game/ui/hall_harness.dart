/// Shared harness for the guild-hall widget tests: an in-memory game log, a
/// fixed clock, a fixed render tier, the shipped voice lines, a fake ledger
/// view and fake habit actions — no database, no plugins, no art.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/reason_codes.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';
import 'package:lootlog/game/ui/hall_habits.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/hall_voice.dart';
import 'package:lootlog/game/ui/town/log_celebration.dart';
import 'package:lootlog/ui/theme.dart';

import '../domain/game_fixtures.dart';

export '../domain/game_fixtures.dart';

/// Saturday 2026-10-03, 11:00 in Vancouver. September and August are open
/// for the spoils ritual.
final DateTime kHallNow = DateTime.utc(2026, 10, 3, 18);

DateTime before(Duration d) => kHallNow.subtract(d);

class FixedTier extends AdventureTierNotifier {
  FixedTier(this.tier);
  final AdventureTier tier;

  @override
  AdventureTier build() => tier;
}

class FakeHabits implements HallHabits {
  FakeHabits({this.result = true});

  final bool result;
  int checkIns = 0;
  final List<CalendarDay> reconciled = [];

  @override
  Future<bool> checkInNoSpend() async {
    checkIns++;
    return result;
  }

  @override
  Future<bool> completeReconcile(CalendarDay day) async {
    reconciled.add(day);
    return result;
  }
}

/// Records which ledger links the hall followed.
class LinkLog {
  final List<String> calls = [];

  HallLinks links() => HallLinks(
        logPurchase: (_) => calls.add('logPurchase'),
        reconcileMonth: (_, m) => calls.add('reconcile ${m.toKey()}'),
        reviewMonth: (_, m) => calls.add('review ${m.toKey()}'),
        planMonth: (_, m) => calls.add('plan ${m.toKey()}'),
        divideLeftovers: (_, m) => calls.add('divide ${m.toKey()}'),
      );

  void openLedger() => calls.add('ledger');
}

/// The shipped hall lines, read off disk.
HallVoice diskVoice() =>
    HallVoice.parse(File(kHallLinesAsset).readAsStringSync());

/// Robin (Adventure, this device) and Sam (Standard: the supply caravan).
HallLedgerView sampleView({bool habits = true, Month? firstBudgetMonth}) =>
    HallLedgerView(
      meId: robin,
      adults: const [
        HallAdult(memberId: robin, name: 'Robin', inAdventure: true),
        HallAdult(memberId: sam, name: 'Sam', inAdventure: false),
      ],
      quests: const [
        HallQuest(questId: 'q1', name: 'Canoe', percent: 55, shared: false),
        HallQuest(
            questId: 'q2',
            name: 'Beach trip',
            percent: 100,
            shared: true,
            completed: true),
      ],
      savingsRunMonths: 4,
      habitsAvailable: habits,
      firstBudgetMonth: firstBudgetMonth,
    );

/// A lived-in hall: 130 gems, a token, a three-day streak, a Lumberyard that
/// has run five hours, a Central Hall upgrading to tier 2, an empty plot,
/// 102 lumber and 100 stone, a wood chest and a daily reward waiting, September's ritual
/// half done, and Sam's caravan deliveries.
List<GameEvent> sampleEvents() {
  var n = 0;
  String id() => 'a${(n++).toString().padLeft(4, '0')}';
  final t0 = before(const Duration(days: 2, hours: 6));
  return [
    granted(id(), when: t0, rewardId: 'seed', gems: 120, tokens: 1,
        materials: MaterialBundle(
            {MaterialKind.lumber: 100, MaterialKind.stone: 100})),
    claimed(id(), 'seed', when: t0),
    for (final d in [2, 1])
      granted(id(),
          when: before(Duration(days: d)),
          rewardId: 'log.daily:$robin:d$d',
          gems: 5,
          reasonCode: GameReasonCodes.dailyLog),
    for (final d in [2, 1]) claimed(id(), 'log.daily:$robin:d$d', when: before(Duration(days: d))),
    granted(id(),
        when: before(const Duration(hours: 1)),
        rewardId: 'log.daily:$robin:today',
        gems: 5,
        reasonCode: GameReasonCodes.dailyLog),
    built(id(), 0, BuildingType.lumberyard,
        when: before(const Duration(hours: 5))),
    built(id(), 1, BuildingType.centralHall,
        when: before(const Duration(hours: 6))),
    built(id(), 1, BuildingType.centralHall,
        tier: 2,
        when: before(const Duration(minutes: 30)),
        completesAt: kHallNow.add(const Duration(minutes: 30))),
    chestGranted(id(), 'week.checkin:$robin:2026-09-28', ChestType.wood,
        when: before(const Duration(hours: 2))),
    ritualStep(id(), Month(2026, 9), RitualStep.reconcile,
        when: before(const Duration(hours: 3))),
    ritualStep(id(), Month(2026, 9), RitualStep.review,
        when: before(const Duration(hours: 3))),
    granted(id(),
        when: before(const Duration(days: 1)),
        actor: sam,
        rewardId: 'caravan:$sam:2026-10-02',
        kind: 'caravan',
        materials: MaterialBundle({MaterialKind.lumber: 2}),
        reasonCode: GameReasonCodes.caravan),
    claimed(id(), 'caravan:$sam:2026-10-02',
        when: before(const Duration(days: 1)), actor: sam),
  ];
}

/// An in-memory log holding [events].
Future<InMemoryGameEventStore> storeWith(List<GameEvent> events) async {
  final store = InMemoryGameEventStore();
  await store.append(events);
  return store;
}

Future<GameState> stateOf(GameEventStore store) async =>
    projectGameState(await store.all());

/// The shipped decoration catalogue, read straight from disk.
final DecorCatalog kShippedCatalog = DecorCatalog.fromJson(
    jsonDecode(File('assets/game/catalog.json').readAsStringSync())
        as Map<String, dynamic>);

/// Stands in for the ledger's count of this adult's purchases: [log] is a
/// purchase being logged.
class LoggedPurchases extends Notifier<int?> {
  @override
  int? build() => 0;

  void log() => state = (state ?? 0) + 1;
}

final testLoggedPurchasesProvider =
    NotifierProvider<LoggedPurchases, int?>(LoggedPurchases.new);

/// The hall's provider overrides. [decorCatalog] is what the catalogue
/// provider resolves to (default: the shipped one, already loaded); pass a
/// not-yet-completed future to test the "still unpacking" state.
List<Override> hallOverrides({
  required InMemoryGameEventStore store,
  HallLedgerView? view,
  AdventureTier tier = AdventureTier.text,
  HallHabits? habits,
  AssetRegistry registry = AssetRegistry.bundled,
  bool registryFails = false,
  AdventureTierNotifier? tierNotifier,
  GameCommandsService? service,
  Future<DecorCatalog>? decorCatalog,
}) {
  var ids = 0;
  return [
    decorCatalogProvider
        .overrideWith((ref) => decorCatalog ?? Future.value(kShippedCatalog)),
    gameEventStoreProvider.overrideWithValue(store),
    gameClockProvider.overrideWithValue(FixedClock(kHallNow)),
    gameCommandsServiceProvider.overrideWithValue(service ??
        GameCommandsService(
          store: store,
          actorId: robin,
          clock: FixedClock(kHallNow),
          stamp: GameEventStamp(
              deviceId: 'test',
              newEventId: () => 'z${(ids++).toString().padLeft(4, '0')}'),
          catalog: kShippedCatalog,
        )),
    hallLedgerViewProvider.overrideWithValue(view ?? sampleView()),
    hallVoiceProvider.overrideWith((ref) async => diskVoice()),
    hallHabitsProvider.overrideWithValue(habits ?? FakeHabits()),
    loggedPurchaseCountProvider
        .overrideWith((ref) => ref.watch(testLoggedPurchasesProvider)),
    adventureTierProvider.overrideWith(() => tierNotifier ?? FixedTier(tier)),
    gameAssetRegistryProvider.overrideWith((ref) async {
      if (registryFails) throw StateError('asset manifest unreadable');
      return registry;
    }),
  ];
}

/// Pumps [home] (default: the hall home) over the overrides and lets the
/// game log's first emission land.
Future<void> pumpHall(
  WidgetTester tester, {
  required InMemoryGameEventStore store,
  HallLedgerView? view,
  AdventureTier tier = AdventureTier.text,
  HallHabits? habits,
  LinkLog? links,
  Widget? home,
  Size size = const Size(420, 2600),
  Future<DecorCatalog>? decorCatalog,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final log = links ?? LinkLog();
  await tester.pumpWidget(ProviderScope(
    overrides: hallOverrides(
        store: store,
        view: view,
        tier: tier,
        habits: habits,
        decorCatalog: decorCatalog),
    child: MaterialApp(
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: home ??
          GameHome(onOpenLedger: log.openLedger, links: log.links()),
    ),
  ));
  await settle(tester);
}

/// Lets async store reads and the voice load finish, then settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}
