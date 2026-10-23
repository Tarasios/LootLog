/// The month-end dungeon: the hero facing goal bosses and debt monsters,
/// with the war chest in the corner. The battle screen tells it what
/// happened ([DungeonGame.showHit]); it never decides or computes money.
library;

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/money.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../battle/month_end_battle.dart';
import '../camera_controls.dart';
import '../pack_atlas.dart';
import '../town/town_components.dart' show KeyedSprite;
import 'dungeon_components.dart';

class DungeonGame extends FlameGame {
  DungeonGame({
    required this.atlas,
    required List<GoalBoss> bosses,
    required List<DebtMonster> debts,
    required this.heroKey,
    this.pictures = const {},
    this.moneyLabel = _plainDollars,
  })  : _bosses = bosses,
        _debts = debts,
        rows = rowsFor(bosses.length + debts.length) {
    cameraControls = CameraControls(worldWidth: columns * kTileSize, worldHeight: rows * kTileSize);
  }

  /// The dungeon is this many tiles wide: three targets abreast.
  static const int columns = 12;
  static const int targetsPerRow = 3;

  /// Tiles from one target row to the next (sprite, HP bar and name).
  static const double targetRowTiles = 4.5;

  /// The first target row starts below the wall.
  static const double firstTargetRowTiles = 1.5;

  /// Rows tall enough for [targetCount] targets with the hero below them.
  static int rowsFor(int targetCount) {
    final targetRows = targetCount <= 0 ? 1 : (targetCount + targetsPerRow - 1) ~/ targetsPerRow;
    return (_heroRowFor(targetRows) + 3).ceil();
  }

  static double _heroRowFor(int targetRows) => firstTargetRowTiles + targetRowTiles * targetRows + 0.5;

  /// The largest whole zoom at which the whole dungeon fits [viewport].
  static int fitZoom(Size viewport, int rows) {
    final fitsWide = viewport.width ~/ (columns * kTileSize);
    final fitsTall = viewport.height ~/ (rows * kTileSize);
    final fit = fitsWide < fitsTall ? fitsWide : fitsTall;
    return fit.clamp(CameraControls.minZoom, CameraControls.maxZoom);
  }

  final PackAtlas atlas;
  final AssetKey heroKey;
  final int rows;
  late final CameraControls cameraControls;

  /// Decoded goal pictures by quest id.
  final Map<String, ui.Image> pictures;

  /// Formats cents for the floating numbers (the screen passes the app's
  /// money formatter).
  final String Function(int cents) moneyLabel;
  List<GoalBoss> _bosses;
  List<DebtMonster> _debts;
  final Map<String, TargetComponent> _targets = {};

  /// Each debt's outstanding amount when the battle began, for its HP bar.
  final Map<String, int> _startingDebtCents = {};

  /// Where the coins fly: the war chest on the wall.
  Vector2 get warChestPosition => Vector2((columns - 1.5) * kTileSize, 0);

  /// The target for [targetId], once loaded (null for carry and bank).
  TargetComponent? targetFor(String targetId) => _targets[targetId];

  static String _plainDollars(int cents) => '\$${Money(cents).format()}';

  @override
  Future<void> onLoad() async {
    await atlas.preload([
      const AssetKey('dungeon', 'floor'),
      const AssetKey('dungeon', 'wall'),
      GameAssetKeys.dungeonWarChest,
      heroKey,
      const AssetKey('boss', 'overbudget'),
      for (final boss in _bosses) boss.spriteKey,
    ]);
    world.add(DungeonBackdrop(atlas, columns: columns, rows: rows));
    world.add(KeyedSprite(
      atlas: atlas,
      assetKey: GameAssetKeys.dungeonWarChest,
      label: 'War chest',
      position: warChestPosition,
      size: Vector2.all(kTileSize),
      priority: 2,
    ));
    final targetRows = (_bosses.length + _debts.length + targetsPerRow - 1) ~/ targetsPerRow;
    world.add(KeyedSprite(
      atlas: atlas,
      assetKey: heroKey,
      label: 'You',
      position: Vector2((columns / 2 - 1) * kTileSize, _heroRowFor(targetRows < 1 ? 1 : targetRows) * kTileSize),
      size: Vector2.all(2 * kTileSize),
      priority: 3,
    ));
    _layoutTargets();
    _syncCamera();
  }

  Vector2 _slotPosition(int slot) => Vector2(
        (0.5 + 4 * (slot % targetsPerRow)) * kTileSize,
        (firstTargetRowTiles + targetRowTiles * (slot ~/ targetsPerRow)) * kTileSize,
      );

  static double _bossRemaining(GoalBoss boss) => boss.targetCents <= 0 ? 0 : boss.remainingCents / boss.targetCents;

  double _debtRemaining(DebtMonster debt) {
    final starting = _startingDebtCents[debt.sliceId] ?? debt.outstandingCents;
    return starting <= 0 ? 0 : debt.outstandingCents / starting;
  }

  void _layoutTargets() {
    var slot = 0;
    for (final boss in _bosses) {
      _targets[boss.questId] = TargetComponent(
        atlas: atlas,
        targetId: boss.questId,
        spriteKey: boss.spriteKey,
        label: boss.name,
        remainingFraction: _bossRemaining(boss),
        picture: pictures[boss.questId],
        revealFraction: boss.revealFraction,
        position: _slotPosition(slot++),
      );
    }
    for (final debt in _debts) {
      _startingDebtCents[debt.sliceId] = debt.outstandingCents;
      _targets[debt.sliceId] = TargetComponent(
        atlas: atlas,
        targetId: debt.sliceId,
        spriteKey: debt.spriteKey,
        label: debt.name,
        remainingFraction: _debtRemaining(debt),
        position: _slotPosition(slot++),
      );
    }
    unawaited(world.addAll(_targets.values));
  }

  /// Plays one confirmed move: what landed floats up from the target (or the
  /// hero, for carry and bank), and the tax flies as coins to the war chest.
  Future<void> showHit({required String targetId, required int landsCents, required int taxCents}) async {
    final target = _targets[targetId];
    final origin = target == null
        ? Vector2(columns / 2 * kTileSize, (rows - 3) * kTileSize)
        : target.position + target.size / 2;
    world.add(FloatingNumber(text: moneyLabel(landsCents), position: origin, colour: DungeonColours.damage));
    if (taxCents > 0) {
      world.add(FloatingNumber(text: moneyLabel(taxCents), position: origin + Vector2(0, 10), colour: DungeonColours.tax));
      final chestCentre = warChestPosition + Vector2.all(kTileSize / 2);
      for (var coin = 0; coin < 5; coin++) {
        world.add(FlyingCoin(from: origin + Vector2(coin * 2.0, 0), destination: chestCentre));
      }
    }
  }

  /// Applies the targets' new HP and reveal after a move.
  void updateTargets(List<GoalBoss> bosses, List<DebtMonster> debts) {
    _bosses = bosses;
    _debts = debts;
    for (final boss in bosses) {
      _targets[boss.questId]?.setProgress(remaining: _bossRemaining(boss), reveal: boss.revealFraction);
    }
    for (final debt in debts) {
      _targets[debt.sliceId]?.setProgress(remaining: _debtRemaining(debt), reveal: 0);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _syncCamera();
  }

  void _syncCamera() {
    camera.viewfinder
      ..zoom = cameraControls.zoom.toDouble()
      ..position = Vector2(columns * kTileSize / 2, rows * kTileSize / 2);
  }
}
