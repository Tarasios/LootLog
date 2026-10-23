import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/providers.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/scenes/town/town_game.dart' show TownsfolkEntry;
import 'package:lootlog/game/ui/town/town_townsfolk.dart';

final _when = DateTime.utc(2026, 7, 1);
var _eventCount = 0;

MemberSet _member(String id, String name, MemberRole role, {bool active = true}) =>
    MemberSet(
      eventId: 'e${(_eventCount++).toString().padLeft(4, '0')}',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _when,
      createdAt: _when.add(Duration(seconds: _eventCount)),
      memberId: id,
      name: name,
      role: role,
      active: active,
    );

Future<List<TownsfolkEntry>> townsfolkFor(List<MemberSet> members) async {
  final container = ProviderContainer(
    overrides: [
      householdStateProvider.overrideWith((ref) => Stream.value(reduce(members))),
    ],
  );
  addTearDown(container.dispose);
  container.listen(householdStateProvider, (_, _) {});
  await container.read(householdStateProvider.future);
  return container.read(townsfolkProvider);
}

void main() {
  test('active dependents and pets walk the town; adults and retired members do not', () async {
    final townsfolk = await townsfolkFor([
      _member('u1', 'Alex', MemberRole.adult),
      _member('d1', 'Kit', MemberRole.dependent),
      _member('d2', 'Gone', MemberRole.dependent, active: false),
      _member('p1', 'Miso', MemberRole.pet),
      _member('p2', 'Old', MemberRole.pet, active: false),
    ]);
    expect(townsfolk, [(name: 'Kit', isPet: false), (name: 'Miso', isPet: true)]);
  });

  test('an adults-only household has no townsfolk', () async {
    expect(await townsfolkFor([_member('u1', 'Alex', MemberRole.adult)]), isEmpty);
  });

  test('nobody walks the town before the household loads', () {
    final container = ProviderContainer(
      overrides: [householdStateProvider.overrideWith((ref) => const Stream.empty())],
    );
    addTearDown(container.dispose);
    expect(container.read(townsfolkProvider), isEmpty);
  });
}
