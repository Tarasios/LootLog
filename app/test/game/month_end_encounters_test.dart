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

Event _member(String id,
        {MemberRole role = MemberRole.adult, String? description}) =>
    MemberSet(
      eventId: 'm-$id',
      deviceId: 'd',
      userId: id,
      occurredAt: day(1),
      createdAt: day(1),
      memberId: id,
      name: id,
      role: role,
      descriptionText: description,
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

  test('encounters name their champion with the member description', () {
    final s = reduce([
      _member('u1', description: 'A steady hand with a ledger.'),
      _member('mochi',
          role: MemberRole.pet, description: 'A fluffy void that eats socks.'),
      _slice('games', const PersonalSlice('u1'), 5000),
      _slice('food', const GroupSlice(), 40000),
      BudgetSliceSet(
        eventId: 's-kibble',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: day(1),
        createdAt: day(1),
        sliceId: 'kibble',
        name: 'kibble',
        ownership: const GroupSlice(),
        limitCents: 3000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
        petOwnerIds: const ['mochi'],
      ),
    ], asOf: day(20));

    final enc = buildEncounters(s, const Month(2026, 1), 'u1');
    final byName = {for (final e in enc) e.name: e};

    // A personal category is its owner's charge, description included.
    expect(byName['games']!.championName, 'u1');
    expect(
        byName['games']!.championDescription, 'A steady hand with a ledger.');

    // A pet-owned category belongs to the pet, not the party.
    expect(byName['kibble']!.championName, 'mochi');
    expect(byName['kibble']!.championDescription,
        'A fluffy void that eats socks.');

    // A plain group category is the whole party's — no single champion.
    expect(byName['food']!.championName, isNull);
    expect(byName['food']!.championDescription, isNull);
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
