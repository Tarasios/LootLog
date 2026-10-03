import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/setup/local_setup.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/household_roster.dart';

final _t = DateTime.utc(2026, 7, 1);
var _n = 0;

MemberSet _member(String id, String name, MemberRole role,
        {bool active = true}) =>
    MemberSet(
      eventId: 'e${(_n++).toString().padLeft(4, '0')}',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _t,
      createdAt: _t.add(Duration(seconds: _n)),
      memberId: id,
      name: name,
      role: role,
      active: active,
    );

LocalSetup _setup(String me, String other) => LocalSetup(
      timezone: 'America/Vancouver',
      user1: UserProfile(userId: me, name: 'Setup-$me'),
      user2: UserProfile(userId: other, name: 'Setup-$other'),
      meUserId: me,
    );

void main() {
  group('partyAdults', () {
    test('lists every active adult, this device first, then by name', () {
      final state = reduce([
        _member('u1', 'Zed', MemberRole.adult),
        _member('u2', 'Blair', MemberRole.adult),
        _member('u3', 'Avery', MemberRole.adult),
        _member('u4', 'Gone', MemberRole.adult, active: false),
        _member('p1', 'Miso', MemberRole.pet),
      ]);
      final adults = partyAdults(state, meUserId: 'u2');
      expect(adults.map((a) => a.id), ['u2', 'u3', 'u1']);
      expect(adults.first.name, 'Blair');
    });

    test('a single-adult household lists that adult once', () {
      final state = reduce([_member('u1', 'Solo', MemberRole.adult)]);
      expect(partyAdults(state, meUserId: 'u1').map((a) => a.id), ['u1']);
    });

    test('legacy households without MemberSet fall back to setup profiles',
        () {
      final state = reduce(const []);
      final adults =
          partyAdults(state, meUserId: 'u1', setup: _setup('u1', 'u2'));
      expect(adults.map((a) => a.id), ['u1', 'u2']);
      expect(adults.map((a) => a.name), ['Setup-u1', 'Setup-u2']);
    });
  });

  group('partyPets', () {
    test('lists active pets by name', () {
      final state = reduce([
        _member('u1', 'Alex', MemberRole.adult),
        _member('p2', 'Tofu', MemberRole.pet),
        _member('p1', 'Miso', MemberRole.pet),
        _member('p3', 'Old', MemberRole.pet, active: false),
      ]);
      expect(partyPets(state).map((p) => p.id), ['p1', 'p2']);
    });
  });

  group('memberNames', () {
    test('names come from the roster, so renames and extra adults show', () {
      final state = reduce([
        _member('u1', 'Alex', MemberRole.adult),
        _member('u1', 'Alexandra', MemberRole.adult),
        _member('u3', 'Casey', MemberRole.adult),
        _member('p1', 'Miso', MemberRole.pet),
      ]);
      final names = memberNames(state, setup: _setup('u1', 'u2'));
      expect(names['u1'], 'Alexandra');
      expect(names['u3'], 'Casey');
      expect(names['p1'], 'Miso');
      // Ids the roster doesn't know still resolve through the legacy profiles.
      expect(names['u2'], 'Setup-u2');
    });
  });
}
