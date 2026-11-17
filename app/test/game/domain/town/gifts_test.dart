import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/clock.dart';
import 'package:lootlog/game/domain/commands/game_commands.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_event_stamp.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';

import '../game_fixtures.dart';

const String _cat = 'u3';

MaterialBundle _lumber(int amount) => MaterialBundle({MaterialKind.lumber: amount});

/// Robin (who keeps the shared town, holding 50 lumber) and Sam are
/// Adventure neighbours; Cat is a Standard adult (in no party).
List<GameEvent> _neighbours() => [
      partyJoined('n01', kHouseholdPartyId, when: at(0)),
      partyJoined('n02', kHouseholdPartyId, when: at(0), actor: sam),
      granted('n03', when: at(1), actor: _cat, gems: 1),
      granted('n04', when: at(1), materials: _lumber(50)),
      claimed('n05', 'reward-n04', when: at(2)),
      townsSplit('n06', robin, when: at(3), welcome: _lumber(10)),
    ];

int _total(GameState state, MaterialKind kind) =>
    state.townOf(robin).materials[kind] + state.townOf(sam).materials[kind];

void main() {
  late List<GameEvent> log;
  var ids = 0;

  GameCommandResult send(String from, String to, MaterialBundle bundle, {int minute = 10}) {
    final result = GameCommands(
      state: projectGameState(log),
      clock: FixedClock(at(minute)),
      actorId: from,
      stamp: GameEventStamp(deviceId: 'dev-1', newEventId: () => 'g${ids++}'),
    ).sendGift(to, bundle);
    log.addAll(result.events);
    return result;
  }

  setUp(() {
    log = _neighbours();
    ids = 0;
  });

  group('sendGift refuses', () {
    test('a gift to oneself', () {
      expect(send(robin, robin, _lumber(5)).rejection, GameRejection.giftToSelf);
    });

    test('a Standard adult or an unknown member, who have no town', () {
      expect(send(robin, _cat, _lumber(5)).rejection, GameRejection.notANeighbour);
      expect(send(robin, 'nobody', _lumber(5)).rejection, GameRejection.notANeighbour);
    });

    test('anything before the towns are split', () {
      log = _neighbours().take(5).toList();
      expect(send(robin, sam, _lumber(5)).rejection, GameRejection.notANeighbour);
    });

    test('an empty or negative bundle', () {
      expect(send(robin, sam, const MaterialBundle.empty()).rejection,
          GameRejection.emptyGift);
      expect(send(robin, sam, _lumber(-3)).rejection, GameRejection.emptyGift);
    });

    test('more than the sender holds', () {
      expect(send(robin, sam, _lumber(51)).rejection, GameRejection.notEnoughMaterials);
      expect(send(sam, robin, _lumber(11)).rejection, GameRejection.notEnoughMaterials);
    });

    test("a neighbour whose Storehouse has no room at all", () {
      final cap = Balance.storehouseCapacityByTier[0];
      log
        ..add(granted('n07', when: at(4), actor: sam, materials: _lumber(cap - 10)))
        ..add(claimed('n08', 'reward-n07', when: at(5), actor: sam));
      expect(send(robin, sam, _lumber(5)).rejection,
          GameRejection.neighbourStorehouseFull);
    });
  });

  group('a gift', () {
    test('moves materials from one town to the other and conserves them', () {
      final before = projectGameState(log);
      final result = send(robin, sam, _lumber(20));
      expect(result.accepted, isTrue);
      final gift = result.events.single as GiftSent;
      expect(gift.toPersonId, sam);
      expect(gift.bundle, _lumber(20));
      final after = projectGameState(log);
      expect(after.townOf(robin).materials, _lumber(30));
      expect(after.townOf(sam).materials, _lumber(30));
      expect(_total(after, MaterialKind.lumber), _total(before, MaterialKind.lumber));
      expect(after.warnings, isEmpty);
    });

    test("moves only what fits the neighbour's Storehouse; the rest stays", () {
      final cap = Balance.storehouseCapacityByTier[0];
      log
        ..add(granted('n07', when: at(4), actor: sam, materials: _lumber(cap - 25)))
        ..add(claimed('n08', 'reward-n07', when: at(5), actor: sam));
      final gift = send(robin, sam, _lumber(40)).events.single as GiftSent;
      expect(gift.bundle, _lumber(15));
      final after = projectGameState(log);
      expect(after.townOf(sam).materials[MaterialKind.lumber], cap);
      expect(after.townOf(robin).materials, _lumber(35));
    });

    test('two racing gifts never overdraw or overfill, and conserve', () {
      final before = projectGameState(log);
      final snapshot = [...log];
      final first = send(robin, sam, _lumber(40), minute: 10).events.single;
      log = [...snapshot];
      final second = send(robin, sam, _lumber(40), minute: 11).events.single;
      log = [...snapshot, first, second];
      final after = projectGameState(log);
      expect(after.townOf(robin).materials, const MaterialBundle.empty());
      expect(after.townOf(sam).materials, _lumber(60));
      expect(_total(after, MaterialKind.lumber), _total(before, MaterialKind.lumber));
      expect(after.warnings.map((warning) => warning.code), [GameWarningCode.giftTrimmed]);

      final random = Random(3);
      for (var round = 0; round < 10; round++) {
        expect(projectGameState([...log]..shuffle(random)), after);
      }
    });

    test('a gift to someone who has since left the party moves nothing', () {
      final result = send(robin, sam, _lumber(20), minute: 10);
      expect(result.accepted, isTrue);
      // Sam switched to Standard on another device before the gift applied.
      log
        ..remove(result.events.single)
        ..add(partyLeft('n09', kHouseholdPartyId, when: at(9), actor: sam))
        ..add(result.events.single);
      final state = projectGameState(log);
      expect(state.townOf(robin).materials, _lumber(50));
      expect(state.townOf(sam).materials, _lumber(10));
      expect(state.warnings.single.code, GameWarningCode.giftIgnored);
    });

    test('a gift to oneself in the log moves nothing', () {
      log.add(GiftSent(
        eventId: 'x1', deviceId: 'd', actorId: robin,
        occurredAt: at(9), createdAt: at(9),
        toPersonId: robin, bundle: _lumber(5),
      ));
      final state = projectGameState(log);
      expect(state.townOf(robin).materials, _lumber(50));
      expect(state.warnings.single.code, GameWarningCode.giftIgnored);
    });
  });
}
