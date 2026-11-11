/// A building's or house's name under it that stays inside the window: on a
/// phone only part of the town shows, so a name whose building straddles
/// the window's edge slides in until it fits rather than running off it.
/// A building wholly out of view keeps its name where it belongs.
library;

import 'package:flame/components.dart';
import 'package:flame/game.dart';

class ViewportClampedLabel extends TextComponent with HasGameReference<FlameGame> {
  ViewportClampedLabel({
    required super.text,
    required Vector2 home,
    required this.ownerWidth,
    super.textRenderer,
  })  : _homeX = home.x,
        super(position: home, anchor: Anchor.topCenter);

  /// Where the label sits in its owner, horizontally.
  final double _homeX;

  /// The width of the building it names.
  final double ownerWidth;

  /// Screen-ish breathing room at the window edge, in world pixels.
  static const double _edgeRoom = 2;

  @override
  void update(double dt) {
    super.update(dt);
    final owner = parent;
    if (owner is! PositionComponent) return;
    final visible = game.camera.visibleWorldRect;
    final ownerLeft = owner.absolutePosition.x;
    final ownerRight = ownerLeft + ownerWidth;
    var centre = ownerLeft + _homeX;
    // Only a building that is at least partly in view pulls its name in.
    if (ownerRight > visible.left && ownerLeft < visible.right) {
      final half = size.x / 2;
      final lowest = visible.left + half + _edgeRoom;
      final highest = visible.right - half - _edgeRoom;
      if (lowest <= highest) centre = centre.clamp(lowest, highest);
    }
    position.x = centre - ownerLeft;
  }
}
