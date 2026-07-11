/// Month-end encounter walkthrough: the pure encounter builder and the
/// data-driven line picker, tested against the shipped asset file.
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/game/month_end_encounters.dart';

DateTime day(int d) => DateTime.utc(2026, 1, d, 18);

Event _member(String id) => MemberSet(
      eventId: 'm-$id',
      deviceId: 'd',
      userId: id,
      occurredAt: day(1),
      createdAt: day(1),
      memberId: id,
      name: id,
      role: MemberRole.adult,
    );

Event _slice(String id, SliceOwnership own, int limit) => BudgetSliceSet(
      eventId: 's-$id',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: day(1),
      createdAt: day(1),
      sliceId: id,
      name: id,
      ownership: own,
      limitCents: limit,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: false,
    );

Event _buy(String slice, int amount, int d) => PurchaseAdded(
      eventId: 'p-$slice-$d',
      deviceId: 'd',
      userId: 'u1',
      occurredAt: day(d),
      createdAt: day(d),
      purchaseId: 'p-$slice-$d',
      target: SliceCharge(slice),
      amountCents: amount,
      shared: false,
    );

void main() {
  test('buildEncounters covers mine and group, ordered, with outcomes', () {
    final s = reduce([
      _member('u1'),
      _member('u2'),
      _slice('games', const PersonalSlice('u1'), 5000),
      _slice('food', const GroupSlice(), 40000),
      _slice('theirs', const PersonalSlice('u2'), 1000),
      _buy('food', 45000, 10),
    ], asOf: day(20));

    final enc = buildEncounters(s, const Month(2026, 1), 'u1');
    expect(enc.map((e) => e.name), ['food', 'games']); // group first; no u2.
    expect(enc[0].enraged, isTrue);
    expect(enc[0].overspendCents, 5000);
    expect(enc[1].flawless, isTrue);
    expect(enc[1].leftoverCents, 5000);
  });

  test('the shipped lines file parses and narrates every outcome', () {
    final json =
        File('assets/game/text/encounter_lines.json').readAsStringSync();
    final lines = EncounterLines.parse(json);
    final rng = Random(7);
    const flawless = EncounterData(
        sliceId: 's', name: 'Games', maxHpCents: 5000, spentCents: 0,
        isGroup: false);
    const enraged = EncounterData(
        sliceId: 's', name: 'Food', maxHpCents: 4000, spentCents: 4500,
        isGroup: true);
    expect(lines.lineFor(flawless, rng: rng), contains('GAMES'));
    expect(lines.lineFor(flawless, rng: rng), contains('\$50.00'));
    expect(lines.lineFor(enraged, rng: rng), contains('\$5.00'));
    // No unfilled placeholders survive.
    for (final e in [flawless, enraged]) {
      expect(lines.lineFor(e, rng: rng), isNot(contains('{')));
    }
  });
}
