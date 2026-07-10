import 'package:lootlog/domain/state.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/vacation/vacation_dashboard.dart';
import 'package:flutter_test/flutter_test.dart';

VacationState vac({
  required List<VacationCategoryState> categories,
  int fundBalanceCents = 100000,
  int daysRemaining = 5,
  int daysTotal = 5,
}) =>
    VacationState(
      vacationId: 'v',
      name: 'Trip',
      fund: const VacationFundEmergency('f'),
      startDate: DateTime.utc(2026, 6, 10),
      endDate: DateTime.utc(2026, 6, 14),
      closed: false,
      categories: categories,
      fundBalanceCents: fundBalanceCents,
      reservedFromFundCents: 0,
      daysTotal: daysTotal,
      daysRemaining: daysRemaining,
    );

VacationCategoryState cat(String name, int limit, int spent) =>
    VacationCategoryState(
      categoryId: name,
      name: name,
      limitCents: limit,
      spentCents: spent,
    );

void main() {
  group('vacationWarnings', () {
    test('none when within budget and fund', () {
      final v = vac(categories: [cat('Food', 10000, 4000)]);
      expect(vacationWarnings(v), isEmpty);
    });

    test('flags total, per-category, and fund over-provisioning in order', () {
      final v = vac(
        categories: [cat('Food', 10000, 15000), cat('Gas', 5000, 4000)],
        fundBalanceCents: -2000,
      );
      expect(vacationWarnings(v), [
        'Over trip budget by \$40.00',
        'Food over by \$50.00',
        'Reserving \$20.00 more than the fund holds',
      ]);
    });
  });

  group('dailyAllowanceLabel', () {
    test('spreads remaining budget across remaining days', () {
      final v = vac(
        categories: [cat('Food', 100000, 40000)],
        daysRemaining: 6,
        daysTotal: 10,
      );
      expect(dailyAllowanceLabel(v), '\$100.00/day for 6 more days');
    });

    test('singular day phrasing', () {
      final v = vac(
        categories: [cat('Food', 100000, 90000)],
        daysRemaining: 1,
      );
      expect(dailyAllowanceLabel(v), '\$100.00/day for 1 more day');
    });

    test('trip over', () {
      final v = vac(categories: [cat('Food', 100000, 40000)], daysRemaining: 0);
      expect(dailyAllowanceLabel(v), 'Trip over');
    });

    test('budget spent', () {
      final v = vac(categories: [cat('Food', 100000, 100000)], daysRemaining: 3);
      expect(dailyAllowanceLabel(v), 'Budget spent — \$0.00/day left');
    });
  });
}
