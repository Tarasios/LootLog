import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_rng.dart';

void main() {
  group('stableHash32', () {
    test('is the FNV-1a hash of the UTF-16 code units', () {
      // FNV-1a 32 reference values (ASCII, so code units == bytes).
      expect(stableHash32(''), 0x811c9dc5);
      expect(stableHash32('a'), 0xe40c292c);
      expect(stableHash32('foobar'), 0xbf9cf968);
    });

    test('stays within 32 bits', () {
      for (final s in ['x', '0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b', 'é漢']) {
        final h = stableHash32(s);
        expect(h, inInclusiveRange(0, 0xffffffff));
      }
    });
  });

  group('GameRng', () {
    test('the same event id yields the same sequence', () {
      final a = GameRng.forEvent('0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b');
      final b = GameRng.forEvent('0190a1b2-c3d4-7e5f-8a9b-0c1d2e3f4a5b');
      expect([for (var i = 0; i < 20; i++) a.nextUint32()],
          [for (var i = 0; i < 20; i++) b.nextUint32()]);
    });

    test('different ids yield different sequences', () {
      final a = GameRng.forEvent('evt-1');
      final b = GameRng.forEvent('evt-2');
      expect([for (var i = 0; i < 5; i++) a.nextUint32()],
          isNot([for (var i = 0; i < 5; i++) b.nextUint32()]));
    });

    test('the sequence is pinned: changing the generator breaks every device '
        'that replays stored outcomes, so these values must never change', () {
      final rng = GameRng(0);
      expect([for (var i = 0; i < 4; i++) rng.nextUint32()], kPinnedSeed0);
      final byId = GameRng.forEvent('pinned-event');
      expect([for (var i = 0; i < 4; i++) byId.nextUint32()], kPinnedEvent);
    });

    test('nextInt stays in range and covers it', () {
      final rng = GameRng.forEvent('range');
      final seen = <int>{};
      for (var i = 0; i < 2000; i++) {
        final v = rng.nextInt(7);
        expect(v, inInclusiveRange(0, 6));
        seen.add(v);
      }
      expect(seen, {0, 1, 2, 3, 4, 5, 6});
    });

    test('nextInt is roughly uniform', () {
      final rng = GameRng.forEvent('uniform');
      final counts = List.filled(4, 0);
      for (var i = 0; i < 8000; i++) {
        counts[rng.nextInt(4)]++;
      }
      for (final c in counts) {
        expect(c, inInclusiveRange(1800, 2200));
      }
    });

    test('range is inclusive at both ends; a one-value range returns it', () {
      final rng = GameRng.forEvent('incl');
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        seen.add(rng.range(3, 5));
      }
      expect(seen, {3, 4, 5});
      expect(rng.range(9, 9), 9);
    });

    test('chance honours 0 and 1000 permille exactly', () {
      final rng = GameRng.forEvent('chance');
      for (var i = 0; i < 200; i++) {
        expect(rng.chance(0), isFalse);
        expect(rng.chance(1000), isTrue);
      }
      var hits = 0;
      for (var i = 0; i < 10000; i++) {
        if (rng.chance(250)) hits++;
      }
      expect(hits, inInclusiveRange(2300, 2700));
    });

    test('pick chooses only from the list', () {
      final rng = GameRng.forEvent('pick');
      for (var i = 0; i < 50; i++) {
        expect(['a', 'b', 'c'], contains(rng.pick(['a', 'b', 'c'])));
      }
    });

    test('rejects empty or negative bounds', () {
      final rng = GameRng(1);
      expect(() => rng.nextInt(0), throwsArgumentError);
      expect(() => rng.range(5, 4), throwsArgumentError);
      expect(() => rng.pick(const <int>[]), throwsArgumentError);
    });
  });
}

/// Pinned outputs of the generator, taken from the reference JavaScript
/// mulberry32 (`Math.imul`) seeded with 0 and with the FNV-1a hash of
/// 'pinned-event' (3800178898). They guard against any change to the
/// algorithm.
const List<int> kPinnedSeed0 = [1144304738, 1416247, 958946056, 627933444];
const List<int> kPinnedEvent = [245587209, 4271276022, 3362445861, 1310272772];
