/// Where a sign hangs over the town scene: its pointer's tip on its anchor,
/// nudged inside the viewport.
library;

import 'package:flutter/widgets.dart';

/// Hangs a tag with its pointer's tip on [anchor], then nudges it inside the
/// viewport so a sign near an edge is never cut off.
class TownTagLayout extends SingleChildLayoutDelegate {
  TownTagLayout(this.anchor);

  final Offset anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.dx - childSize.width / 2).clamp(
      0.0,
      (size.width - childSize.width).clamp(0.0, double.infinity),
    );
    final top = (anchor.dy - childSize.height).clamp(
      0.0,
      (size.height - childSize.height).clamp(0.0, double.infinity),
    );
    return Offset(left.roundToDouble(), top.roundToDouble());
  }

  @override
  bool shouldRelayout(TownTagLayout oldDelegate) => oldDelegate.anchor != anchor;
}
