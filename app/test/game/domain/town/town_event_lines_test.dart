import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/town/daily_event.dart';
import 'package:lootlog/game/domain/town/festival.dart';
import 'package:lootlog/game/domain/town/town_event_lines.dart';

final _shame = RegExp(
  r'\b(fail|failed|bad|lazy|should have|overspent|wasted|shame|guilt)\b',
  caseSensitive: false,
);

Map<String, dynamic> _shippedFile() =>
    jsonDecode(File('assets/game/text/town_events.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('every flavour key a daily event can roll has a built-in line', () {
    for (final kind in DailyEventKind.values) {
      final keys = dailyEventFlavourKeys(kind);
      expect(keys, hasLength(greaterThanOrEqualTo(3)), reason: kind.name);
      for (final key in keys) {
        expect(
          TownEventLines.defaults.line(key).trim(),
          isNotEmpty,
          reason: key,
        );
      }
    }
  });

  test('every festival tier, and the joint bonus, has a built-in line', () {
    for (final tier in FestivalTier.values) {
      expect(festivalFlavourKey(tier), 'festival.${tier.name}');
      expect(
        TownEventLines.defaults.line(festivalFlavourKey(tier)).trim(),
        isNotEmpty,
        reason: tier.name,
      );
    }
    expect(
      TownEventLines.defaults.line(kJointFestivalFlavourKey).trim(),
      isNotEmpty,
    );
  });

  test('the shipped town_events.json carries the built-in lines', () {
    final shipped = TownEventLines.fromJson(_shippedFile());
    expect(shipped, TownEventLines.defaults);
    for (final key in TownEventLines.defaults.keys) {
      expect(
        _shippedFile()[key],
        TownEventLines.defaults.line(key),
        reason: key,
      );
    }
  });

  test('a missing, blank or non-text key keeps its built-in line', () {
    final lines = TownEventLines.fromJson({
      'trader.1': '',
      'trader.2': 7,
      'visitor.1': 'A friend waves from the gate.',
    });
    expect(lines.line('trader.1'), TownEventLines.defaults.line('trader.1'));
    expect(lines.line('trader.2'), TownEventLines.defaults.line('trader.2'));
    expect(
      lines.line('windfall.3'),
      TownEventLines.defaults.line('windfall.3'),
    );
    expect(lines.line('visitor.1'), 'A friend waves from the gate.');
  });

  test("a key this build lacks reads as its kind's first line", () {
    // A newer device may roll a line this build has never shipped.
    expect(
      TownEventLines.defaults.line('trader.9'),
      TownEventLines.defaults.line('trader.1'),
    );
    expect(TownEventLines.defaults.line('nonsense'), isEmpty);
  });

  test('no line shames or blames', () {
    for (final key in TownEventLines.defaults.keys) {
      expect(
        _shame.hasMatch(TownEventLines.defaults.line(key)),
        isFalse,
        reason: key,
      );
    }
  });
}
