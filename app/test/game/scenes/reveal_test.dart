import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/scenes/dungeon/reveal.dart';

void main() {
  test('nothing saved reveals nothing', () {
    expect(revealedSourceRect(100, 80, 0).height, 0);
  });

  test('30% saved reveals the bottom 30%', () {
    expect(revealedSourceRect(100, 80, 0.3), const Rect.fromLTWH(0, 56, 100, 24));
  });

  test('fractions outside 0..1 are clamped', () {
    expect(revealedSourceRect(100, 80, 1.7), const Rect.fromLTWH(0, 0, 100, 80));
    expect(revealedSourceRect(100, 80, -1).height, 0);
  });
}
