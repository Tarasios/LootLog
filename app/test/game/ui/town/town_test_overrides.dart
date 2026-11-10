/// Provider overrides for the town shell tests: the guild-hall harness's
/// in-memory game log, fixed clock and fixed tier, plus a fixed game state and
/// a registry that never decodes an image (unless a test hands one in).
///
/// [TownTestHarness] is the richer setup for the decoration screens: a live
/// in-memory log for Alex (with optional starting gems and the starter set),
/// the real catalogue, and a container for reading providers in tests.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/money.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/data/game_providers.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/town/quest_board_view.dart';
import 'package:lootlog/game/domain/town/town_ledger.dart';
import 'package:lootlog/game/domain/town/town_tags.dart';
import 'package:lootlog/game/scenes/town/town_game.dart' show TownsfolkEntry;
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_providers.dart';
import 'package:lootlog/game/ui/hall_habits.dart';
import 'package:lootlog/game/ui/hall_ledger_view.dart';
import 'package:lootlog/game/ui/town/town_ledger_provider.dart';
import 'package:lootlog/game/ui/town/town_townsfolk.dart';

import '../hall_harness.dart';

/// The hall harness overrides plus [game] (default: the lived-in sample hall;
/// or, with a [liveStore], the state projected live from that log so commands
/// show up),
/// no townsfolk (unless given), [battle] as the month-end battle (default:
/// none, so the gate is closed), and [registry] (default: [AssetRegistry.empty], so every
/// sprite is a labelled placeholder and no image is decoded).
///
/// The decoration catalogue defaults to [DecorCatalog.empty] so the shell
/// tests never claim a starter set; hand in [catalog] to opt in. [view] and
/// [service] replace the hall harness's Robin view and command service.
/// [ledger] is the town's ledger figures (default: [kSampleTownLedger]);
/// [billsOn] gives the bills due soon as of a day (default: none). [clock]
/// replaces the harness's fixed clock.
/// Robin's town ledger: a Canoe goal 40% of the way, one calm and one
/// enraged monster, $70 in the gold pouch and $1234.56 in the war chest.
const TownLedger kSampleTownLedger = TownLedger(
  board: QuestBoardView(
    goals: [
      QuestBoardGoal(
        questId: 'canoe',
        name: 'Canoe',
        percent: 40,
        remaining: Money(78000),
        target: Money(130000),
        shared: false,
      ),
    ],
    monsters: [
      QuestBoardMonster(
        categoryId: 'groceries',
        name: 'Groceries',
        remaining: Money(60000),
        limit: Money(80000),
        enraged: false,
        group: true,
        colorArgb: 0xFF72B84E,
      ),
      QuestBoardMonster(
        categoryId: 'fun',
        name: 'Fun',
        remaining: Money.zero,
        limit: Money(20000),
        enraged: true,
        group: false,
        colorArgb: 0xFFCF5E53,
        overspend: Money(1200),
      ),
    ],
  ),
  goldPouch: Money(7000),
  warChest: Money(123456),
);

List<Override> townTestOverrides({
  required AdventureTier tier,
  GameState? game,
  InMemoryGameEventStore? liveStore,
  bool registryFails = false,
  AssetRegistry registry = AssetRegistry.empty,
  List<TownsfolkEntry> townsfolk = const [],
  AdventureTierNotifier? tierNotifier,
  DecorCatalog catalog = DecorCatalog.empty,
  HallLedgerView? view,
  GameCommandsService? service,
  MonthEndBattle? battle,
  HallHabits? habits,
  TownLedger ledger = kSampleTownLedger,
  List<TownBill> Function(CalendarDay today)? billsOn,
  Clock? clock,
}) {
  final state = game ?? projectGameState(sampleEvents());
  return [
    ...hallOverrides(
      store: liveStore ?? InMemoryGameEventStore(),
      tier: tier,
      registry: registry,
      registryFails: registryFails,
      tierNotifier: tierNotifier,
      view: view,
      service: service,
      habits: habits,
      decorCatalog: Future.value(catalog),
      clock: clock,
    ),
    if (liveStore == null)
      gameStateProvider.overrideWith((ref) => Stream.value(state)),
    townsfolkProvider.overrideWithValue(townsfolk),
    monthEndBattleProvider.overrideWithValue(battle),
    townLedgerProvider.overrideWith((ref, month) => ledger),
    townBillsProvider.overrideWith((ref, today) => billsOn?.call(today) ?? const []),
    townTagLinesProvider.overrideWith((ref) async => TownTagLines.defaults),
  ];
}

/// Alex (this device's adult, Adventure) and Sam (their partner) over a live
/// in-memory game log, with the real decoration catalogue. One command
/// service is shared by every [overrides] call, so event ids never collide.
class TownTestHarness {
  TownTestHarness._({
    required this.store,
    required this.catalog,
    required this.service,
    required this.view,
  });

  /// This device's adult.
  static const String kMeId = 'alex';

  /// Their partner.
  static const String kPartnerId = 'sam';

  final InMemoryGameEventStore store;
  final DecorCatalog catalog;
  final GameCommandsService service;
  final HallLedgerView view;

  late final ProviderContainer container;

  String get meId => kMeId;
  String get partnerId => kPartnerId;

  /// Builds the harness: [gems] are credited to Alex as a granted-and-claimed
  /// reward, [starterClaimed] adds the starter furniture, and
  /// [firstBudgetMonth] is the household's first budgeted month (default:
  /// unknown, so every open month-end counts).
  static Future<TownTestHarness> create({
    int gems = 0,
    bool starterClaimed = false,
    Month? firstBudgetMonth,
  }) async {
    final catalog = DecorCatalog.fromJson(
      jsonDecode(File('assets/game/catalog.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    final store = InMemoryGameEventStore();
    var eventNumber = 0;
    final service = GameCommandsService(
      store: store,
      actorId: kMeId,
      clock: FixedClock(kHallNow),
      stamp: GameEventStamp(
        deviceId: 'test',
        newEventId: () => 'z${(eventNumber++).toString().padLeft(4, '0')}',
      ),
      catalog: catalog,
    );
    final harness = TownTestHarness._(
      store: store,
      catalog: catalog,
      service: service,
      view: HallLedgerView(
        meId: kMeId,
        adults: const [
          HallAdult(memberId: kMeId, name: 'Alex', inAdventure: true),
          HallAdult(memberId: kPartnerId, name: 'Sam', inAdventure: true),
        ],
        habitsAvailable: true,
        firstBudgetMonth: firstBudgetMonth,
      ),
    );
    if (gems > 0) {
      await store.append([
        granted(
          'g0001',
          when: before(const Duration(days: 1)),
          actor: kMeId,
          rewardId: 'seed-gems',
          gems: gems,
        ),
        claimed(
          'g0002',
          'seed-gems',
          when: before(const Duration(days: 1)),
          actor: kMeId,
        ),
      ]);
    }
    if (starterClaimed) await service.claimStarterSet();
    harness.container = ProviderContainer(
      overrides: harness.overrides(tier: AdventureTier.pixel),
    );
    addTearDown(harness.container.dispose);
    await harness.container.read(decorCatalogProvider.future);
    return harness;
  }

  /// Overrides for a `ProviderScope` over this harness's log.
  List<Override> overrides({
    required AdventureTier tier,
    AdventureTierNotifier? tierNotifier,
    bool registryFails = false,
    AssetRegistry registry = AssetRegistry.empty,
    MonthEndBattle? battle,
  }) => townTestOverrides(
    tier: tier,
    battle: battle,
    tierNotifier: tierNotifier,
    registry: registry,
    registryFails: registryFails,
    liveStore: store,
    catalog: catalog,
    view: view,
    service: service,
  );
}
