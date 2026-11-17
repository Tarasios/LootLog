/// Cheers between neighbouring towns: a purely cosmetic "well done" an
/// Adventure adult sends a neighbour, at most once a day per pair, which the
/// neighbour sees in their inbox. It never moves a gem or a material.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/cheers.dart';

import '../game_fixtures.dart';

const String _cat = 'u3';

/// Robin and Sam are Adventure neighbours; Cat is a Standard adult.
List<GameEvent> _neighbours() => [
      partyJoined('n01', kHouseholdPartyId, when: at(0)),
      partyJoined('n02', kHouseholdPartyId, when: at(0), actor: sam),
      granted('n03', when: at(1), actor: _cat, gems: 1),
      townsSplit('n06', robin, when: at(3), welcome: const MaterialBundle.empty()),
    ];

void main() {
  late List<GameEvent> log;
  var ids = 0;

  GameCommandResult cheer(String from, String to, DateTime when, {String device = 'dev-1'}) {
    final result = GameCommands(
      state: projectGameState(log),
      clock: FixedClock(when),
      actorId: from,
      stamp: GameEventStamp(deviceId: device, newEventId: () => '$device-c${ids++}'),
    ).cheer(to);
    log.addAll(result.events);
    return result;
  }

  setUp(() {
    log = _neighbours();
    ids = 0;
  });

  test('a cheer is recorded for the neighbour, from the sender, on the day', () {
    final result = cheer(robin, sam, at(10));
    expect(result.accepted, isTrue);
    final sent = result.events.single as CheerSent;
    expect(sent.toPersonId, sam);
    expect(sent.day, GameDay.fromInstant(at(10)));
    final received = cheersFor(projectGameState(log), sam);
    expect(received.map((c) => (c.fromId, c.day)), [(robin, GameDay.fromInstant(at(10)))]);
    expect(cheersFor(projectGameState(log), robin), isEmpty);
  });

  test('at most one cheer a day for each sender and neighbour', () {
    expect(cheer(robin, sam, at(10)).accepted, isTrue);
    expect(cheer(robin, sam, at(30)).rejection, GameRejection.alreadyCheeredToday);
    expect(cheered(projectGameState(log), fromId: robin, toId: sam, day: GameDay.fromInstant(at(30))),
        isTrue);
    // The neighbour may cheer back, and tomorrow is a new day.
    expect(cheer(sam, robin, at(31)).accepted, isTrue);
    expect(cheer(robin, sam, onDay(1)).accepted, isTrue);
    expect(cheersFor(projectGameState(log), sam), hasLength(2));
  });

  test('two devices cheering the same day converge on one cheer, in any order', () {
    final day = _neighbours();
    final phone = cheer(robin, sam, at(10), device: 'phone').events;
    log = [...day];
    final desktop = cheer(robin, sam, at(20), device: 'desktop').events;
    final merged = projectGameState([...day, ...phone, ...desktop]);
    expect(merged, projectGameState([...desktop, ...day, ...phone].reversed));
    expect(cheersFor(merged, sam), hasLength(1));
    expect(cheersFor(merged, sam).single.at, at(10), reason: 'the earliest copy stands');
  });

  test('refuses oneself, a Standard adult and a stranger', () {
    expect(cheer(robin, robin, at(10)).rejection, GameRejection.cheerToSelf);
    expect(cheer(robin, _cat, at(10)).rejection, GameRejection.notANeighbour);
    expect(cheer(robin, 'nobody', at(10)).rejection, GameRejection.notANeighbour);
    expect(cheer(_cat, robin, at(10)).rejection, GameRejection.notANeighbour,
        reason: 'a Standard adult has no town to cheer from');
  });

  test('a cheer moves nothing: gems, materials and rewards are unchanged', () {
    final before = projectGameState(log);
    cheer(robin, sam, at(10));
    final after = projectGameState(log);
    for (final who in [robin, sam]) {
      expect(after.person(who), before.person(who));
      expect(after.townOf(who), before.townOf(who));
    }
    expect(after.decor, before.decor);
  });

  test('cheersFor lists the newest first and can stop at a day', () {
    cheer(robin, sam, at(10));
    cheer(robin, sam, onDay(2));
    final state = projectGameState(log);
    expect(cheersFor(state, sam).map((c) => c.day),
        [GameDay.fromInstant(onDay(2)), GameDay.fromInstant(at(10))]);
    expect(cheersFor(state, sam, since: GameDay.fromInstant(onDay(1))), hasLength(1));
  });
}
