/// A strip of festival bunting for a dialog's scene well: [rows] strings of
/// flags (one for a market day, up to three for a grand festival), drawn at
/// a whole-number pixel scale like the town's art.
library;

import 'package:flutter/material.dart';

import '../../scenes/town/pennant_painter.dart';
import '../kit/kit.dart';

class PennantStrip extends StatelessWidget {
  const PennantStrip({super.key, this.rows = 1});

  final int rows;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AdventureTokens.grass,
    child: CustomPaint(painter: _PennantPainter(rows), size: Size.infinite),
  );
}

class _PennantPainter extends CustomPainter {
  _PennantPainter(this.rows);

  final int rows;

  /// Each art pixel is this many screen pixels.
  static const double _scale = 3;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(_scale);
    final width = (size.width / _scale).floorToDouble();
    final height = size.height / _scale;
    final gap = height / (rows + 1);
    for (var row = 0; row < rows; row++) {
      final y = (gap * (row + 0.6)).roundToDouble();
      paintPennants(canvas, Offset(2, y), Offset(width - 2, y), sag: 4, colourOffset: row * 2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PennantPainter oldDelegate) => oldDelegate.rows != rows;
}
