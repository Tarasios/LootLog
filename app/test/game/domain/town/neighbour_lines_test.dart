import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/neighbour_lines.dart';

final _shame = RegExp(
  r'\b(fail|failed|bad|lazy|should have|inactive|idle|absent|missing|lost|missed|penalty|shame|guilt)\b',
  caseSensitive: false,
);

void main() {
  const lines = NeighbourLines.defaults;

  test('the shipped neighbours.json carries the built-in lines', () {
    final shipped =
        jsonDecode(File('assets/game/text/neighbours.json').readAsStringSync()) as Map<String, dynamic>;
    expect(NeighbourLines.fromJson(shipped), lines);
    for (final key in lines.keys) {
      expect(shipped[key], lines.line(key), reason: key);
    }
  });

  test('a missing or blank key keeps its built-in line, and fills its names', () {
    final read = NeighbourLines.fromJson({'cheer.received': ' ', 'visit.header': 'Guest of {name}'});
    expect(read.line('cheer.received', {'name': 'Sam'}), 'Sam cheered your town');
    expect(read.line('visit.header', {'name': 'Sam'}), 'Guest of Sam');
  });

  test('nothing shames or blames a neighbour', () {
    for (final key in lines.keys) {
      expect(_shame.hasMatch(lines.line(key)), isFalse, reason: '$key: ${lines.line(key)}');
    }
  });

  test('every line is listed in docs/voice-lines.md', () {
    final doc = File('../docs/voice-lines.md').readAsStringSync();
    for (final key in lines.keys) {
      expect(doc.contains('`$key`'), isTrue, reason: key);
    }
  });
}
