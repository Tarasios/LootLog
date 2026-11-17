/// The road to the neighbours: who the signpost leads to, the caravan camp
/// a Standard adult keeps beside it, and the room a gift can fill.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_event.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/neighbours.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_view.dart';

import '../game_fixtures.dart';

const String _cat = 'u3';

const _robin = TownAdult(memberId: robin, name: 'Robin', inAdventure: true);
const _sam = TownAdult(memberId: sam, name: 'Sam', inAdventure: true);
const _catStandard = TownAdult(memberId: _cat, name: 'Cat', inAdventure: false);

List<GameEvent> _split() => [
      partyJoined('n01', kHouseholdPartyId, when: at(0)),
      partyJoined('n02', kHouseholdPartyId, when: at(0), actor: sam),
      townsSplit('n03', robin, when: at(1), welcome: const MaterialBundle.empty()),
    ];

void main() {
  test('alone: no neighbours, no signpost, nothing to explain', () {
    final state = projectGameState(_split());
    expect(neighboursOf(state, robin, const [_robin]), isEmpty);
    final view = TownView.from(state, robin, const [_robin], at(5));
    expect(view.showsSignpost, isFalse);
    expect(view.showsCaravanCamp, isFalse);
    expect(view.targetAt(TownLayout.standard.signpost!), isNull);
  });

  test('an Adventure neighbour is visitable through the signpost', () {
    final state = projectGameState(_split());
    final neighbours = neighboursOf(state, robin, const [_robin, _sam]);
    expect(neighbours.map((n) => (n.memberId, n.name, n.canVisit)), [(sam, 'Sam', true)]);
    final view = TownView.from(state, robin, const [_robin, _sam], at(5), neighbours: neighbours);
    expect(view.showsSignpost, isTrue);
    expect(view.targetAt(TownLayout.standard.signpost!), const SignpostTarget());
  });

  test('a Standard adult is a caravan camp beside the road, never a visit', () {
    final state = projectGameState(_split());
    final neighbours = neighboursOf(state, robin, const [_robin, _catStandard]);
    expect(neighbours.single.canVisit, isFalse);
    expect(neighbours.single.isCaravan, isTrue);
    final view = TownView.from(state, robin, const [_robin, _catStandard], at(5), neighbours: neighbours);
    expect(view.showsCaravanCamp, isTrue);
    expect(view.showsSignpost, isFalse, reason: 'no town to visit');
    expect(view.targetAt(TownLayout.standard.caravanCamp!), isNull);
  });

  test('before the towns split, the road leads nowhere yet', () {
    final state = projectGameState(_split().take(2));
    expect(neighboursOf(state, robin, const [_robin, _sam]).single.canVisit, isFalse);
  });

  test('the signpost and the camp stand by the east road, apart from the gate', () {
    const layout = TownLayout.standard;
    final signpost = layout.signpost!;
    final camp = layout.caravanCamp!;
    expect(signpost, isNot(layout.gate));
    expect(camp, isNot(layout.gate));
    expect(signpost.column, greaterThanOrEqualTo(layout.columns - 4), reason: 'at the east edge');
    for (final cell in [signpost, camp]) {
      expect(layout.groundAt(cell), TownGround.grass, reason: '$cell');
      final view = TownView.from(projectGameState(const []), robin, const [_robin], at(0));
      expect(view.targetAt(cell), isNull, reason: 'no plot or house at $cell');
    }
    expect(TownLayout.farmland.signpost, isNull);
  });

  test('a gift can fill what the neighbour\'s Storehouse still holds room for', () {
    final state = projectGameState([
      ..._split(),
      granted('n04', when: at(2), actor: sam, materials: MaterialBundle({MaterialKind.lumber: 30})),
      claimed('n05', 'reward-n04', when: at(3), actor: sam),
    ]);
    final capacity = Balance.storehouseCapacityByTier[0];
    expect(giftRoom(state, sam, MaterialKind.lumber, at(5)), capacity - 30);
    expect(giftRoom(state, sam, MaterialKind.stone, at(5)), capacity);
  });
}
