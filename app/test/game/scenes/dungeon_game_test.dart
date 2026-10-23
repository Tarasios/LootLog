import 'package:flame/cache.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/battle/month_end_battle.dart';
import 'package:lootlog/game/scenes/dungeon/dungeon_components.dart';
import 'package:lootlog/game/scenes/dungeon/dungeon_game.dart';
import 'package:lootlog/game/scenes/pack_atlas.dart';

const canoe = GoalBoss(
  questId: 'canoe',
  name: 'Canoe',
  targetCents: 130000,
  progressCents: 0,
  spriteKey: AssetKey('boss', 'goal', 'entertainment'),
  shared: false,
);

const funDebt = DebtMonster(sliceId: 'fun', name: 'Fun', outstandingCents: 5000);

DungeonGame buildGame() => DungeonGame(
      atlas: PackAtlas(AssetRegistry.empty, Images(prefix: 'assets/game/')),
      bosses: const [canoe],
      debts: const [funDebt],
      heroKey: const AssetKey('hero', 'body'),
    );

void main() {
  testWithGame<DungeonGame>('draws every boss and debt monster with no art at all', buildGame, (game) async {
    await game.ready();
    final targets = game.world.children.whereType<TargetComponent>().toList();
    expect(targets.map((target) => target.targetId), ['canoe', 'fun']);
    expect(game.targetFor('canoe')!.remainingFraction, 1);
    expect(game.targetFor('fun')!.remainingFraction, 1);
  });

  testWithGame<DungeonGame>('a hit floats the landed amount and flies the tax to the war chest', buildGame,
      (game) async {
    await game.ready();
    await game.showHit(targetId: 'canoe', landsCents: 12000, taxCents: 3000);
    await game.ready();
    final numbers = game.world.children.whereType<FloatingNumber>().map((number) => number.text);
    expect(numbers, containsAll([r'$120.00', r'$30.00']));
    expect(game.world.children.whereType<FlyingCoin>(), hasLength(5));
  });

  testWithGame<DungeonGame>('an untaxed hit sends no coins', buildGame, (game) async {
    await game.ready();
    await game.showHit(targetId: 'fun', landsCents: 5000, taxCents: 0);
    await game.ready();
    expect(game.world.children.whereType<FlyingCoin>(), isEmpty);
  });

  testWithGame<DungeonGame>('updateTargets lowers HP and raises the reveal', buildGame, (game) async {
    await game.ready();
    game.updateTargets([canoe.afterLanding(65000)], [funDebt.afterLanding(5000)]);
    expect(game.targetFor('canoe')!.remainingFraction, 0.5);
    expect(game.targetFor('canoe')!.revealFraction, 0.5);
    expect(game.targetFor('fun')!.remainingFraction, 0);
  });

  test('the whole dungeon fits a phone at a whole zoom', () {
    final rows = DungeonGame.rowsFor(2);
    expect(DungeonGame.fitZoom(const Size(390, 600), rows), 2);
    expect(DungeonGame.fitZoom(const Size(100, 100), rows), 1);
  });
}
