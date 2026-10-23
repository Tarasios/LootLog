import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/party_sync.dart';
import 'package:lootlog/game/domain/rewards/reward_engine.dart';

import 'game_fixtures.dart';

void main() {
  var n = 0;
  final stamp = GameEventStamp(
      deviceId: 'dev', newEventId: () => 'p${(n++).toString().padLeft(4, '0')}');

  test('Adventure adults join, Standard adults stay out; idempotent', () {
    final log = <GameEvent>[];
    const party = Party([
      PartyAdult(robin, inAdventure: true),
      PartyAdult(sam, inAdventure: false),
    ]);
    final out = partyMembershipEvents(
        projectGameState(log), party, FixedClock(at(0)), stamp);
    expect(out, hasLength(1));
    expect((out.single as PartyJoined).actorId, robin);
    expect((out.single as PartyJoined).partyId, kHouseholdPartyId);
    log.addAll(out);
    expect(
        partyMembershipEvents(
            projectGameState(log), party, FixedClock(at(1)), stamp),
        isEmpty);
  });

  test('switching to Standard leaves; switching back rejoins', () {
    final log = <GameEvent>[
      partyJoined('j', kHouseholdPartyId, when: at(0)),
    ];
    final left = partyMembershipEvents(projectGameState(log),
        const Party([PartyAdult(robin, inAdventure: false)]), FixedClock(at(5)),
        stamp);
    expect(left.single, isA<PartyLeft>());
    log.addAll(left);
    expect(projectGameState(log).person(robin).partyId, isNull);
    final back = partyMembershipEvents(projectGameState(log),
        const Party([PartyAdult(robin, inAdventure: true)]), FixedClock(at(9)),
        stamp);
    expect(back.single, isA<PartyJoined>());
  });

  test('adults not in the party list are untouched', () {
    final log = <GameEvent>[partyJoined('j', kHouseholdPartyId, when: at(0))];
    expect(
        partyMembershipEvents(projectGameState(log), const Party([]),
            FixedClock(at(1)), stamp),
        isEmpty);
  });
}
