/// Charge choices carry their main category's colour (for the Adventure
/// log-purchase dialog's chips); destinations with no main category carry none.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/entry/charge_choice.dart';

void main() {
  final at = DateTime.utc(2026, 11, 3, 18);

  BudgetSliceSet category(String id, {String? mainCategoryId}) =>
      BudgetSliceSet(
        eventId: 'slice-$id',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: at,
        createdAt: at,
        sliceId: id,
        name: id,
        ownership: const PersonalSlice('u1'),
        mainCategoryId: mainCategoryId,
        limitCents: 10000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
      );

  test('a category takes its main category colour; others take none', () {
    final state = reduce([
      category('groceries', mainCategoryId: 'food'),
      category('loose'),
    ]);
    final choices = {
      for (final group in buildChargeGroups(state, 'u1', asOf: at))
        for (final choice in group.choices) choice.label: choice,
    };
    expect(choices['groceries']!.colorArgb, 0xFFF28E2B);
    expect(choices['loose']!.colorArgb, isNull);
    expect(choices.values.where((choice) => choice.kind == ChargeGroupKind.vault).single.colorArgb, isNull);
  });
}
