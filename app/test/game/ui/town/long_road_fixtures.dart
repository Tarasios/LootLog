/// Robin's town far down the long road, for the stage-3 screens' tests and
/// goldens: grown to [tier] a month ago, with full stores, every civic
/// quarter the tier opens bought, and (optionally) some buildings, a
/// workshop job and Castle stages.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_store.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/hall_common.dart' show HallLinks;
import 'package:lootlog/game/ui/town/town_shell.dart';

import '../../domain/game_fixtures.dart' show built;
import '../../domain/town/growth_fixtures.dart';
import '../hall_harness.dart' show before, claimed, granted, robin, sampleEvents;
import 'town_test_overrides.dart';

/// Every material in plenty, and goods for a Castle stage.
final MaterialBundle kPlenty = MaterialBundle({for (final kind in MaterialKind.values) kind: 2900});
final GoodsBundle kCrates = GoodsBundle({for (final kind in GoodsKind.values) kind: 2000});

/// The civic quarters a [tier] town may own.
List<String> quartersFor(TownTier tier) => [
      for (final district in kDistricts)
        if (district.purchasable && district.id != kFarmlandDistrictId && tier.index >= district.requiredTier.index)
          district.id,
    ];

DateTime _ago(int days) => before(Duration(days: days));

/// Robin's town at [tier] with everything bought; [extra] events follow.
List<GameEvent> longRoadEvents(TownTier tier, {List<GameEvent> extra = const [], bool goods = false}) => [
      ...sampleEvents(),
      for (final reached in TownTier.values.skip(1).take(tier.index))
        tierReached('t-${reached.name}', reached, when: _ago(200 - reached.index)),
      // A tier-5 storehouse on the spare starting plot holds the plenty.
      for (var level = 1; level <= 5; level++)
        built('store-$level', 2, BuildingType.storehouse, when: _ago(56 - level), tier: level),
      granted('plenty', when: _ago(50), rewardId: 'plenty', gems: 5000, materials: kPlenty),
      claimed('plenty-claim', 'plenty', when: _ago(50)),
      districtPurchased('d-farmland', kFarmlandDistrictId, when: _ago(49)),
      for (final id in quartersFor(tier)) districtPurchased('d-$id', id, when: _ago(49)),
      if (goods) ...[
        civicBuilt('loft', kMarketRowDistrictId, 4, CivicBuildingType.workshop, when: _ago(48)),
        RefiningStarted(
          eventId: 'crates',
          deviceId: 'dev-1',
          actorId: robin,
          occurredAt: _ago(47),
          createdAt: _ago(47),
          districtId: kMarketRowDistrictId,
          plotIndex: 4,
          recipeId: 'planks',
          batches: 1,
          input: const MaterialBundle.empty(),
          output: kCrates,
          completesAt: _ago(47),
        ),
        goodsCollected('crates-in', 4, 'crates', kCrates, when: _ago(46)),
      ],
      ...extra,
    ];

/// The town shell on [store], pixel tier, no ambient life.
Widget longRoadHost(InMemoryGameEventStore store, {HallLinks links = const HallLinks(), bool popups = false}) =>
    ProviderScope(
      overrides: townTestOverrides(tier: AdventureTier.pixel, liveStore: store, loopPopups: popups),
      child: MaterialApp(home: TownShell(onOpenLedger: () {}, links: links, ambientLife: false)),
    );
