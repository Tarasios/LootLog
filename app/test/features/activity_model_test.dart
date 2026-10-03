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

  group('savings lines', () {
    final at = DateTime.utc(2026, 7, 10, 18);
    test('covers and borrowing read in plain language', () {
      final titles = feedTitles([
        ShortfallCovered(
          eventId: 's-1',
          deviceId: 'd',
          userId: 'u-robin',
          occurredAt: at,
          createdAt: at,
          purchaseId: 'p1',
          source: const GeneralCover(),
          amountCents: 5000,
        ),
        AllowanceAdvanceProposed(
          eventId: 's-2',
          deviceId: 'd',
          userId: 'u-robin',
          occurredAt: at.add(const Duration(minutes: 1)),
          createdAt: at.add(const Duration(minutes: 1)),
          advanceId: 'a1',
          byUserId: 'u-robin',
          sliceId: 'clothes',
          amountCents: 5000,
          months: 2,
        ),
        AllowanceAdvanceApproved(
          eventId: 's-3',
          deviceId: 'd',
          userId: 'u-robin',
          occurredAt: at.add(const Duration(minutes: 2)),
          createdAt: at.add(const Duration(minutes: 2)),
          advanceId: 'a1',
          byUserId: 'u-robin',
        ),
      ]);
      expect(titles, [
        'Robin covered part of a purchase from general savings',
        'Robin asked to borrow from future months (2 months)',
        'Robin approved borrowing from future months',
      ]);
    });
  });
}
