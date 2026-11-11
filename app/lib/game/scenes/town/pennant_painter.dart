/// Festival bunting, drawn in code: a sagging string between two points
/// with little triangular flags hanging off it in the palette's festival
/// colours. Deterministic (the colours cycle in a fixed order) and pixel
/// crisp (no anti-aliasing, whole-pixel flags). Shared by the town scene's
/// bunting over the square and the festival dialog's scene strip.
library;

import 'dart:ui';

/// The flags' colours, in the order they hang (DawnBringer-16 picks that sit
/// with the Tiny Town art).
const List<Color> kPennantColours = [
  Color(0xFFD04648), // red
  Color(0xFFDAD45E), // yellow
  Color(0xFF597DCE), // blue
  Color(0xFF6DAA2C), // green
  Color(0xFFD27D2C), // orange
];

const Color _kStringColour = Color(0xFF442434);

/// Draws one string of flags from [start] to [end], sagging [sag] pixels in
/// the middle, a flag every [spacing] pixels, each [flagWidth] wide and
/// [flagHeight] tall. [colourOffset] shifts the colour cycle so neighbouring
/// strings differ.
void paintPennants(
  Canvas canvas,
  Offset start,
  Offset end, {
  double sag = 3,
  double spacing = 6,
  double flagWidth = 4,
  double flagHeight = 5,
  int colourOffset = 0,
}) {
  final string = Paint()
    ..isAntiAlias = false
    ..color = _kStringColour
    ..strokeWidth = 1;
  final flag = Paint()..isAntiAlias = false;
  final length = (end - start).distance;
  final count = (length / spacing).floor();
  Offset pointAt(double t) {
    final straight = Offset.lerp(start, end, t)!;
    // A parabola: zero at both ends, [sag] in the middle.
    return straight.translate(0, sag * 4 * t * (1 - t));
  }

  var previous = start;
  for (var step = 1; step <= 16; step++) {
    final next = pointAt(step / 16);
    canvas.drawLine(previous, next, string);
    previous = next;
  }
  for (var index = 1; index < count; index++) {
    final top = pointAt(index / count);
    final left = top.dx.roundToDouble() - (flagWidth / 2).floorToDouble();
    final y = top.dy.roundToDouble();
    flag.color = kPennantColours[(index + colourOffset) % kPennantColours.length];
    canvas.drawPath(
      Path()
        ..moveTo(left, y)
        ..lineTo(left + flagWidth, y)
        ..lineTo(left + flagWidth / 2, y + flagHeight)
        ..close(),
      flag,
    );
  }
}
