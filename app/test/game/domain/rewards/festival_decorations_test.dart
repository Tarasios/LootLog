import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/decor/catalog.dart';
import 'package:lootlog/game/domain/decor/decor_values.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/rewards/festival_decorations.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

const _ada = 'ada';
const _ben = 'ben';
const GameDay _week = GameDay(2026, 10, 5);
final DateTime _saturday = DateTime.utc(2026, 10, 10, 18);

const _duo = Party([
  PartyAdult(_ada, inAdventure: true),
  PartyAdult(_ben, inAdventure: true),
]);

DecorItem _festivalItem(String id) => DecorItem(
  id: id,
  name: id,
  kind: DecorKind.townDecor,
  rarity: DecorRarity.rare,
  assetKey: const AssetKey('town_decor', 'lamp_post'),
  exclusive: true,
  tags: const {'festival'},
);

final DecorCatalog _catalog = DecorCatalog([
  _festivalItem('town_festival_lantern'),
  _festivalItem('town_festival_arch'),
  _festivalItem('town_festival_banner'),
  const DecorItem(
    id: 'rug_round',
    name: 'Round rug',
    kind: DecorKind.furniture,
    rarity: DecorRarity.common,
    assetKey: AssetKey('furniture', 'rug'),
    priceGems: 8,
  ),
]);

FestivalHeld _held(String id, String who, FestivalTier tier) => FestivalHeld(
  eventId: id,
  deviceId: 'dev-1',
  actorId: who,
  occurredAt: _saturday,
  createdAt: _saturday,
  week: _week,
  tier: tier,
  weekdaysLogged: tier == FestivalTier.grandFestival ? 5 : 3,
);

List<GameEvent> _evaluate(List<GameEvent> log, DecorCatalog catalog) {
  var ids = 0;
  return const FestivalDecorations().evaluate(
    projectGameState(log),
    _duo,
    catalog,
    FixedClock(_saturday.add(const Duration(hours: 1))),
    GameEventStamp(deviceId: 'dev-2', newEventId: () => 'fd-${ids++}'),
  );
}

void main() {
  test('a grand festival brings one festival decoration to town', () {
    final out = _evaluate([
      _held('h1', _ada, FestivalTier.grandFestival),
    ], _catalog);
    final acquired = out.single as ItemAcquired;
    expect(acquired.actorId, _ada);
    expect(acquired.acquisitionId, 'festival.decor:$_ada:2026-10-05');
    expect(acquired.acquisitionId, festivalDecorAcquisitionId(_ada, _week));
    expect(
      _catalog.festivalPool.map((item) => item.id),
      contains(acquired.itemId),
    );
    expect(acquired.source, DecorSource.milestone);
    expect(acquired.toTown, isTrue);
  });

  test('is granted once, and the same on every device', () {
    final log = <GameEvent>[_held('h1', _ada, FestivalTier.grandFestival)];
    final first = _evaluate(log, _catalog);
    expect(
      (_evaluate(log, _catalog).single as ItemAcquired).itemId,
      (first.single as ItemAcquired).itemId,
    );
    expect(_evaluate([...log, ...first], _catalog), isEmpty);
  });

  test('a market day or a fair brings no decoration', () {
    expect(
      _evaluate([
        _held('h1', _ada, FestivalTier.fair),
        _held('h2', _ben, FestivalTier.marketDay),
      ], _catalog),
      isEmpty,
    );
  });

  test('nothing when the catalogue has no festival items', () {
    final plain = DecorCatalog([
      for (final item in _catalog.items)
        if (!item.tags.contains('festival')) item,
    ]);
    expect(
      _evaluate([_held('h1', _ada, FestivalTier.grandFestival)], plain),
      isEmpty,
    );
  });

  test('a decoration the town already has becomes gems instead', () {
    final onlyOne = DecorCatalog([_festivalItem('town_festival_lantern')]);
    final owned = ItemAcquired(
      eventId: 'a0',
      deviceId: 'dev-1',
      actorId: _ben,
      occurredAt: _saturday,
      createdAt: _saturday,
      acquisitionId: 'earlier',
      itemId: 'town_festival_lantern',
      source: DecorSource.milestone,
      toTown: true,
    );
    final out = _evaluate([
      owned,
      _held('h1', _ada, FestivalTier.grandFestival),
    ], onlyOne);
    // The grant is always the item; the projection turns a duplicate into
    // gems, so devices that disagreed about ownership still converge.
    final grant = out.single as ItemAcquired;
    expect(grant.acquisitionId, festivalDecorAcquisitionId(_ada, _week));
    final state = projectGameState([
      owned,
      _held('h1', _ada, FestivalTier.grandFestival),
      ...out,
    ]);
    expect(state.decor.townOwned['town_festival_lantern'], 1);
    expect(state.person(_ada).gems, Balance.duplicateDecorGems);
    expect(state.decor.seenAcquisitionIds, contains(grant.acquisitionId));
    final again = _evaluate([
      owned,
      _held('h1', _ada, FestivalTier.grandFestival),
      ...out,
    ], onlyOne);
    expect(again, isEmpty);
  });

  test('two devices that disagreed about ownership converge', () {
    final onlyOne = DecorCatalog([_festivalItem('town_festival_lantern')]);
    final owned = ItemAcquired(
      eventId: 'a0',
      deviceId: 'dev-1',
      actorId: _ben,
      occurredAt: _saturday,
      createdAt: _saturday,
      acquisitionId: 'earlier',
      itemId: 'town_festival_lantern',
      source: DecorSource.milestone,
      toTown: true,
    );
    final held = _held('h1', _ada, FestivalTier.grandFestival);
    // One device already had the lantern, the other had not heard of it.
    final knowing = _evaluate([owned, held], onlyOne);
    final unaware = [
      for (final event in _evaluate([held], onlyOne))
        if (event is ItemAcquired)
          ItemAcquired(
            eventId: 'other-${event.eventId}',
            deviceId: 'dev-3',
            actorId: event.actorId,
            occurredAt: event.occurredAt,
            createdAt: event.createdAt,
            acquisitionId: event.acquisitionId,
            itemId: event.itemId,
            source: event.source,
            toTown: event.toTown,
          ),
    ];
    final merged = projectGameState([owned, held, ...knowing, ...unaware]);
    final reversed = projectGameState([...unaware, ...knowing, held, owned]);
    for (final state in [merged, reversed]) {
      expect(state.decor.townOwned['town_festival_lantern'], 1);
      expect(state.person(_ada).gems, Balance.duplicateDecorGems);
    }
  });

  test('catalogue entries tagged "festival" form the festival pool', () {
    final parsed = DecorCatalog.fromJson({
      'items': [
        {
          'id': 'town_festival_lantern',
          'name': 'Festival lantern',
          'kind': 'townDecor',
          'rarity': 'rare',
          'asset': 'town_decor.lamp_post.default.idle',
          'exclusive': true,
          'tags': ['festival'],
        },
        {
          'id': 'rug_round',
          'name': 'Round rug',
          'kind': 'furniture',
          'rarity': 'common',
          'price': 8,
          'asset': 'furniture.rug.default.idle',
        },
        {
          'id': 'bad_tags',
          'name': 'Bad tags',
          'kind': 'furniture',
          'rarity': 'common',
          'asset': 'furniture.rug.default.idle',
          'tags': 'festival',
        },
      ],
    });
    expect(parsed.items.map((item) => item.id), [
      'town_festival_lantern',
      'rug_round',
    ]);
    expect(parsed.festivalPool.map((item) => item.id), [
      'town_festival_lantern',
    ]);
    expect(parsed.chestPool(DecorRarity.rare), isEmpty);
    expect(parsed.shopPool.map((item) => item.id), ['rug_round']);
  });
}
