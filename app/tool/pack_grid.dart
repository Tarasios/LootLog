// Usage: dart run tool/pack_grid.dart <sheet.png> <cellSize> <spacing> <out.png>
// Writes a copy of the sheet scaled 4x with each cell labelled "column,row".
import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  if (arguments.length != 4) {
    stderr.writeln('usage: pack_grid <sheet.png> <cellSize> <spacing> <out.png>');
    exit(64);
  }
  final sheet = img.decodePng(File(arguments[0]).readAsBytesSync())!;
  final cellSize = int.parse(arguments[1]);
  final spacing = int.parse(arguments[2]);
  const zoom = 4;
  final scaled = img.copyResize(sheet,
      width: sheet.width * zoom,
      height: sheet.height * zoom,
      interpolation: img.Interpolation.nearest);
  final stride = cellSize + spacing;
  final columns = (sheet.width + spacing) ~/ stride;
  final rows = (sheet.height + spacing) ~/ stride;
  for (var column = 0; column < columns; column++) {
    for (var row = 0; row < rows; row++) {
      final left = column * stride * zoom;
      final top = row * stride * zoom;
      img.drawRect(scaled,
          x1: left, y1: top, x2: left + cellSize * zoom - 1, y2: top + cellSize * zoom - 1,
          color: img.ColorRgba8(255, 0, 255, 160));
      img.drawString(scaled, '$column,$row',
          font: img.arial14, x: left + 2, y: top + 2, color: img.ColorRgba8(255, 255, 0, 255));
    }
  }
  File(arguments[3]).writeAsBytesSync(img.encodePng(scaled));
  stdout.writeln('$columns x $rows cells -> ${arguments[3]}');
}
