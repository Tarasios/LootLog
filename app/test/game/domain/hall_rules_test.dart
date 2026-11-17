/// The working shift: producers work the whole household-local day on days
/// someone logged and a short shift on days nobody did.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/config/balance.dart';
import 'package:lootlog/game/domain/game_projection.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/domain/hall_rules.dart';
import 'package:lootlog/game/domain/reason_codes.dart';

import 'game_fixtures.dart';

const GameDay october5 = GameDay(2026, 10, 5);
const GameDay october6 = GameDay(2026, 10, 6);
const GameDay october7 = GameDay(2026, 10, 7);

/// Vancouver midnight of an October 2026 day (PDT, UTC-7).
DateTime octoberMidnight(int day) => DateTime.utc(2026, 10, day, 7);

/// [hours] (and [minutes]) after Vancouver midnight on October [day].
DateTime octoberLocal(int day, int hours, [int minutes = 0]) =>
    octoberMidnight(day).add(Duration(hours: hours, minutes: minutes));

int shortShiftMinutes() => Balance.shortShiftHours * 60;

/// A hall whose plot 0 holds [type] at [tier], last collected at [from].
HallState hallWith(
  BuildingType type, {
  required DateTime from,
  int tier = 1,
  DateTime? completesAt,
}) => HallState(
  plots: {
    0: PlotState(
      0,
      BuildingState(
        type: type,
        tier: tier,
        startedAt: from,
        completesAt: completesAt ?? from,
      ),
    ),
  },
  materials: const MaterialBundle.empty(),
  lastCollectedAt: {buildingIdForPlot(0): from},
);

List<int> ratesOf(BuildingType type, MaterialKind kind) =>
    Balance.buildings[type]!.productionPerHour[kind]!;

void main() {
  test('the shifts are a full day and eight hours', () {
    expect(Balance.fullShiftHours, 24);
    expect(Balance.shortShiftHours, 8);
  });

  group('workedMinutes', () {
    test('every day active works every elapsed minute, as before', () {
      final from = DateTime.utc(2026, 10, 5, 10, 17, 30);
      final to = DateTime.utc(2026, 10, 8, 3, 5, 10);
      final everyDay = {
        for (
          var day = GameDay.fromInstant(from);
          day <= GameDay.fromInstant(to);
          day = day.next()
        )
          day,
      };
      expect(workedMinutes(from, to, everyDay), to.difference(from).inMinutes);
    });

    test('an idle day works exactly the short shift', () {
      expect(
        workedMinutes(octoberMidnight(5), octoberMidnight(6), const {}),
        shortShiftMinutes(),
      );
    });

    test('a stretch from an active evening into an idle morning', () {
      // 20:00 to midnight on the active day, then the first 8 h of the next.
      final worked = workedMinutes(octoberLocal(5, 20), octoberLocal(6, 12), {
        october5,
      });
      expect(worked, 4 * 60 + shortShiftMinutes());
    });

    test(
      'starting after the short shift on an idle day works nothing that day',
      () {
        expect(
          workedMinutes(octoberLocal(5, 9), octoberLocal(5, 23), const {}),
          0,
        );
        // ...and picks up at the next midnight.
        expect(
          workedMinutes(octoberLocal(5, 9), octoberLocal(6, 3), const {}),
          3 * 60,
        );
      },
    );

    test('an empty or backwards window works nothing', () {
      expect(
        workedMinutes(octoberLocal(5, 3), octoberLocal(5, 3), const {}),
        0,
      );
      expect(
        workedMinutes(octoberLocal(5, 4), octoberLocal(5, 3), const {}),
        0,
      );
    });

    test('the days follow the household clock across daylight saving', () {
      // 2026-11-01 falls back: a 25-hour day. 2026-03-08 springs forward: 23.
      const fallBack = GameDay(2026, 11, 1);
      final fallBackStart = DateTime.utc(2026, 11, 1, 7);
      final fallBackEnd = DateTime.utc(2026, 11, 2, 8);
      expect(workedMinutes(fallBackStart, fallBackEnd, {fallBack}), 25 * 60);
      expect(
        workedMinutes(fallBackStart, fallBackEnd, const {}),
        shortShiftMinutes(),
      );

      const springForward = GameDay(2026, 3, 8);
      final springStart = DateTime.utc(2026, 3, 8, 8);
      final springEnd = DateTime.utc(2026, 3, 9, 7);
      expect(workedMinutes(springStart, springEnd, {springForward}), 23 * 60);
    });

    test('the same inputs always give the same answer', () {
      final daysOneWay = {october5, october7};
      final daysOtherWay = {october7, october5};
      final first = workedMinutes(
        octoberLocal(4, 5),
        octoberLocal(8, 2),
        daysOneWay,
      );
      final second = workedMinutes(
        octoberLocal(4, 5),
        octoberLocal(8, 2),
        daysOtherWay,
      );
      expect(first, second);
      // Oct 4 idle: 05:00-08:00 = 3 h; Oct 5 24 h; Oct 6 8 h; Oct 7 24 h;
      // Oct 8 idle: 00:00-02:00 = 2 h.
      expect(first, (3 + 24 + 8 + 24 + 2) * 60);
    });
  });

  group('uncollectedProduction', () {
    test('an idle day yields exactly the short shift of output', () {
      final hall = hallWith(BuildingType.quarry, from: octoberMidnight(5));
      final made = uncollectedProduction(
        hall,
        0,
        octoberMidnight(6),
        activeDays: const {},
      );
      expect(
        made[MaterialKind.stone],
        ratesOf(BuildingType.quarry, MaterialKind.stone)[0] *
            Balance.shortShiftHours,
      );
    });

    test('an active day yields the whole day of output', () {
      final hall = hallWith(BuildingType.quarry, from: octoberMidnight(5));
      final made = uncollectedProduction(
        hall,
        0,
        octoberMidnight(6),
        activeDays: {october5},
      );
      expect(
        made[MaterialKind.stone],
        ratesOf(BuildingType.quarry, MaterialKind.stone)[0] * 24,
      );
    });

    test('a tier change mid-shift splits the worked minutes by tier', () {
      // Upgrade to tier 2 completes at 04:00 on an idle day: hours 0-4 at
      // tier 1, hours 4-8 at tier 2, then the crew rests.
      final hall = hallWith(
        BuildingType.mine,
        from: octoberMidnight(5),
        tier: 2,
        completesAt: octoberLocal(5, 4),
      );
      final rates = ratesOf(BuildingType.mine, MaterialKind.ore);
      final made = uncollectedProduction(
        hall,
        0,
        octoberLocal(5, 20),
        activeDays: const {},
      );
      expect(made[MaterialKind.ore], rates[0] * 4 + rates[1] * 4);
    });

    test('collectableNow trims the shift output to the Storehouse room', () {
      final hall = hallWith(BuildingType.lumberyard, from: octoberMidnight(5));
      final ready = collectableNow(
        hall,
        0,
        octoberLocal(7, 23),
        activeDays: {october5, october6, october7},
      );
      expect(ready[MaterialKind.lumber], Balance.storehouseCapacityByTier[0]);
    });
  });

  group('shiftSummary', () {
    test(
      'reports worked against possible minutes since the last collection',
      () {
        final hall = hallWith(BuildingType.quarry, from: octoberMidnight(5));
        final summary = shiftSummary(
          hall,
          0,
          octoberLocal(6, 12),
          activeDays: {october5},
        );
        expect(summary.workedMinutes, 24 * 60 + shortShiftMinutes());
        expect(summary.possibleMinutes, 36 * 60);
      },
    );

    test('is zero for an empty plot or a building that makes nothing', () {
      final hall = hallWith(BuildingType.forge, from: octoberMidnight(5));
      final summary = shiftSummary(
        hall,
        0,
        octoberLocal(6, 12),
        activeDays: const {},
      );
      expect(summary.workedMinutes, 0);
      expect(summary.possibleMinutes, 0);
      final empty = shiftSummary(
        hall,
        3,
        octoberLocal(6, 12),
        activeDays: const {},
      );
      expect(empty.possibleMinutes, 0);
    });
  });

  group('GameState.townActiveDaysOf', () {
    test('is worked out once per streak and follows a new state', () {
      final first = projectGameState([
        granted('g1', when: octoberLocal(5, 9), reasonCode: GameReasonCodes.dailyLog,
            rewardId: 'log.daily:$robin:2026-10-05'),
      ]);
      expect(identical(first.townActiveDaysOf(robin), first.townActiveDaysOf(robin)), isTrue);
      final next = first.apply(
        granted('g2', when: octoberLocal(6, 9), reasonCode: GameReasonCodes.dailyLog,
            rewardId: 'log.daily:$robin:2026-10-06'),
      );
      expect(next.townActiveDaysOf(robin), {october5, october6});
      expect(first.townActiveDaysOf(robin), {october5});
    });

    test(
      "holds only the town's own adult's logged days, freeze-covered days out",
      () {
        final state = projectGameState([
          granted(
            'g1',
            when: octoberLocal(5, 9),
            reasonCode: GameReasonCodes.dailyLog,
            rewardId: 'log.daily:$robin:2026-10-05',
          ),
          granted(
            'g2',
            when: octoberLocal(7, 9),
            actor: sam,
            reasonCode: GameReasonCodes.noSpendCheckIn,
            rewardId: 'checkin.no_spend:$sam:2026-10-07',
          ),
          freezeUsed('f1', october6, when: octoberLocal(7, 10)),
        ]);
        expect(state.townActiveDaysOf(robin), {october5});
        expect(state.townActiveDaysOf(sam), {october7});

        // The frozen day works only the short shift.
        final hall = hallWith(BuildingType.quarry, from: octoberMidnight(6));
        final made = uncollectedProduction(
          hall,
          0,
          octoberMidnight(7),
          activeDays: state.townActiveDaysOf(robin),
        );
        expect(
          made[MaterialKind.stone],
          ratesOf(BuildingType.quarry, MaterialKind.stone)[0] *
              Balance.shortShiftHours,
        );
      },
    );

    test("a Standard partner's caravan day no longer extends anyone's shift", () {
      final state = projectGameState([
        granted(
          'g1',
          when: octoberLocal(8, 9),
          actor: sam,
          kind: 'caravan',
          reasonCode: GameReasonCodes.caravan,
          rewardId: caravanRewardId(sam, october6),
        ),
      ]);
      expect(state.townActiveDaysOf(robin), isEmpty);
      expect(state.townActiveDaysOf(sam), isEmpty);
    });

    test('caravanRewardDay reads back only caravan reward ids', () {
      expect(caravanRewardDay(caravanRewardId(sam, october6)), october6);
      expect(caravanRewardDay('log.daily:$sam:2026-10-06'), isNull);
      expect(caravanRewardDay('caravan:$sam:not-a-day'), isNull);
    });
  });
}
