import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/daily_event.dart';

import '../game_fixtures.dart';

final GameDay _today = GameDay.fromInstant(at(0));

DailyEventOffered _offered(
  String eventId,
  DailyEventKind kind, {
  GameDay? day,
  MaterialBundle gives = const MaterialBundle.empty(),
  Loot receives = Loot.none,
  int? plotIndex,
  String actor = robin,
}) {
  final offerDay = day ?? _today;
  return DailyEventOffered(
    eventId: eventId,
    deviceId: 'dev-1',
    actorId: actor,
    occurredAt: at(0),
    createdAt: at(0),
    offerId: dailyEventOfferId(actor, offerDay),
    day: offerDay,
    kind: kind,
    gives: gives,
    receives: receives,
    flavourKey: '${kind.name}.1',
    plotIndex: plotIndex,
  );
}

class _Town {
  _Town(List<GameEvent> seed) : log = [...seed];

  final List<GameEvent> log;
  DateTime now = at(30);
  int _ids = 0;

  GameState get state => projectGameState(log);

  GameCommandResult resolve(
    String offerId, {
    required bool accept,
    String actor = robin,
  }) {
    final result = GameCommands(
      state: state,
      clock: FixedClock(now),
      actorId: actor,
      stamp: GameEventStamp(
        deviceId: 'dev-test',
        newEventId: () => 'z${_ids++}',
      ),
    ).resolveDailyEvent(offerId, accept: accept);
    if (result.accepted) log.addAll(result.events);
    return result;
  }
}

void main() {
  final offerId = dailyEventOfferId(robin, _today);

  test('accepting a visitor adds its gift and resolves the offer', () {
    final town = _Town([
      _offered(
        'o1',
        DailyEventKind.visitor,
        receives: Loot(
          gems: 2,
          materials: MaterialBundle({MaterialKind.herbs: 5}),
        ),
      ),
    ]);
    final result = town.resolve(offerId, accept: true);
    expect(result.accepted, isTrue);
    final resolved = result.events.single as DailyEventResolved;
    expect(resolved.offerId, offerId);
    expect(resolved.accepted, isTrue);
    final state = town.state;
    expect(state.person(robin).gems, 2);
    expect(state.hall.materials[MaterialKind.herbs], 5);
    expect(state.offerFor(robin, _today), isNull);
  });

  test(
    'accepting a windfall adds what the producer made, up to the Storehouse',
    () {
      final town = _Town([
        collected(
          'c1',
          'plot-0',
          MaterialBundle({MaterialKind.lumber: 140}),
          when: at(0),
        ),
        _offered(
          'o1',
          DailyEventKind.windfall,
          receives: Loot(materials: MaterialBundle({MaterialKind.lumber: 40})),
          plotIndex: 0,
        ),
      ]);
      final result = town.resolve(offerId, accept: true);
      expect(result.accepted, isTrue);
      final resolved = result.events.single as DailyEventResolved;
      expect(
        resolved.received.materials,
        MaterialBundle({MaterialKind.lumber: 10}),
      );
      expect(town.state.hall.materials[MaterialKind.lumber], 150);
      expect(
        town.state.warnings.where(
          (warning) => warning.code == GameWarningCode.materialsCapped,
        ),
        isEmpty,
      );
    },
  );

  test('a trader takes the goods and hands over the swap', () {
    final town = _Town([
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.lumber: 30}),
        when: at(0),
      ),
      _offered(
        'o1',
        DailyEventKind.trader,
        gives: MaterialBundle({MaterialKind.lumber: 20}),
        receives: Loot(materials: MaterialBundle({MaterialKind.ore: 8})),
      ),
    ]);
    final result = town.resolve(offerId, accept: true);
    expect(result.accepted, isTrue);
    final resolved = result.events.single as DailyEventResolved;
    expect(resolved.paid, MaterialBundle({MaterialKind.lumber: 20}));
    final pool = town.state.hall.materials;
    expect(pool[MaterialKind.lumber], 10);
    expect(pool[MaterialKind.ore], 8);
  });

  test('a trader is refused without the goods, and the offer stays', () {
    final town = _Town([
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.lumber: 5}),
        when: at(0),
      ),
      _offered(
        'o1',
        DailyEventKind.trader,
        gives: MaterialBundle({MaterialKind.lumber: 20}),
        receives: Loot(materials: MaterialBundle({MaterialKind.ore: 8})),
      ),
    ]);
    final result = town.resolve(offerId, accept: true);
    expect(result.rejection, GameRejection.notEnoughMaterials);
    expect(town.state.offerFor(robin, _today), isNotNull);
  });

  test('declining resolves the offer with nothing moved', () {
    final town = _Town([
      collected(
        'c1',
        'plot-0',
        MaterialBundle({MaterialKind.lumber: 30}),
        when: at(0),
      ),
      _offered(
        'o1',
        DailyEventKind.trader,
        gives: MaterialBundle({MaterialKind.lumber: 20}),
        receives: Loot(materials: MaterialBundle({MaterialKind.ore: 8})),
      ),
    ]);
    final result = town.resolve(offerId, accept: false);
    expect(result.accepted, isTrue);
    final resolved = result.events.single as DailyEventResolved;
    expect(resolved.accepted, isFalse);
    expect(resolved.paid.isEmpty, isTrue);
    expect(resolved.received.isEmpty, isTrue);
    expect(
      town.state.hall.materials,
      MaterialBundle({MaterialKind.lumber: 30}),
    );
    expect(town.state.offerFor(robin, _today), isNull);
  });

  test('an offer resolves once: accept or decline cannot be repeated', () {
    final town = _Town([
      _offered('o1', DailyEventKind.visitor, receives: const Loot(gems: 2)),
    ]);
    expect(town.resolve(offerId, accept: true).accepted, isTrue);
    expect(
      town.resolve(offerId, accept: true).rejection,
      GameRejection.unknownOffer,
    );
    expect(
      town.resolve(offerId, accept: false).rejection,
      GameRejection.unknownOffer,
    );
    expect(town.state.person(robin).gems, 2);
  });

  test('an unknown offer, or someone else\'s, is refused', () {
    final town = _Town([
      _offered(
        'o1',
        DailyEventKind.visitor,
        receives: const Loot(gems: 2),
        actor: sam,
      ),
    ]);
    expect(
      town.resolve('daily.event:nobody:2026-10-01', accept: true).rejection,
      GameRejection.unknownOffer,
    );
    expect(
      town.resolve(dailyEventOfferId(sam, _today), accept: true).rejection,
      GameRejection.unknownOffer,
    );
  });

  test("yesterday's offer can no longer be taken", () {
    final yesterday = _today.previous();
    final town = _Town([
      _offered(
        'o1',
        DailyEventKind.visitor,
        receives: const Loot(gems: 2),
        day: yesterday,
      ),
    ]);
    expect(
      town.resolve(dailyEventOfferId(robin, yesterday), accept: true).rejection,
      GameRejection.offerExpired,
    );
  });

  test('a second device resolving the same offer credits it once', () {
    final town = _Town([
      _offered('o1', DailyEventKind.visitor, receives: const Loot(gems: 2)),
    ]);
    final before = town.state;
    final first = town.resolve(offerId, accept: true);
    // The other device decided from the state before the first resolve.
    final second = GameCommands(
      state: before,
      clock: FixedClock(town.now),
      actorId: robin,
      stamp: GameEventStamp(deviceId: 'dev-2', newEventId: () => 'zz-2'),
    ).resolveDailyEvent(offerId, accept: true);
    final merged = projectGameState([...town.log, ...second.events]);
    expect(first.accepted && second.accepted, isTrue);
    expect(merged.person(robin).gems, 2);
  });
}
