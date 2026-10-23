/// Goldens for the guild-hall home in both render tiers, phone and desktop.
/// With no real art every sprite renders its text card (zero-art is the
/// state the app ships in), so these are deterministic.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/game_home.dart';

import 'hall_harness.dart';

void main() {
  for (final tier in AdventureTier.values) {
    for (final (name, size) in [
      ('phone', const Size(390, 2900)),
      ('desktop', const Size(1200, 1700)),
    ]) {
      testWidgets('hall home golden (${tier.name}, $name)', (tester) async {
        await pumpHall(tester,
            store: await storeWith(sampleEvents()), tier: tier, size: size);
        await expectLater(
          find.byType(GameHome),
          matchesGoldenFile('goldens/hall_home_${tier.name}_$name.png'),
        );
      });
    }
  }
}
