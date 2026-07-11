import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/activity/activity_model.dart';

void main() {
  var counter = 0;
  MemberSet member({
    required String memberId,
    required String name,
    MemberRole role = MemberRole.adult,
    bool active = true,
    String? sprite,
    String? description,
  }) {
    counter++;
    return MemberSet(
      eventId: 'evt-${counter.toString().padLeft(4, '0')}',
      deviceId: 'dev-1',
      userId: 'u-robin',
      occurredAt: DateTime.utc(2026, 7, 1).add(Duration(minutes: counter)),
      createdAt: DateTime.utc(2026, 7, 1).add(Duration(minutes: counter)),
      memberId: memberId,
      name: name,
      role: role,
      active: active,
      customSpriteSha256: sprite,
      descriptionText: description,
    );
  }

  List<String> feedTitles(List<Event> events) {
    final state = reduce(events);
    final items = buildActivityFeed(
      state,
      events,
      userNames: const {'u-robin': 'Robin'},
      meUserId: 'u-robin',
    );
    // The feed is newest-first; reverse to chronological for easy asserts.
    return items.reversed.map((i) => i.title).toList();
  }

  group('member lines', () {
    test('first MemberSet reads as an add', () {
      final titles = feedTitles([member(memberId: 'm1', name: 'Riley')]);
      expect(titles, ['Robin added Riley to the party']);
    });

    test('a later MemberSet reads as an update, not an add', () {
      final titles = feedTitles([
        member(memberId: 'm1', name: 'Riley'),
        member(memberId: 'm1', name: 'Riley R.'),
      ]);
      expect(titles, [
        'Robin added Riley to the party',
        'Robin updated Riley R.',
      ]);
    });

    test('a sprite-only change reads as a portrait update', () {
      final titles = feedTitles([
        member(memberId: 'm1', name: 'Riley'),
        member(memberId: 'm1', name: 'Riley', sprite: 'a' * 64),
      ]);
      expect(titles, [
        'Robin added Riley to the party',
        "Robin updated Riley's portrait",
      ]);
    });

    test('deactivation reads as retirement', () {
      final titles = feedTitles([
        member(memberId: 'm1', name: 'Riley'),
        member(memberId: 'm1', name: 'Riley', active: false),
      ]);
      expect(titles, [
        'Robin added Riley to the party',
        'Robin retired Riley from the party',
      ]);
    });
  });
}
