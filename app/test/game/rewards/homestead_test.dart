import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/state.dart';
import 'package:lootlog/game/rewards/homestead.dart';
import 'package:flutter_test/flutter_test.dart';

const _u1 = 'u1';

class _Seq {
  int _n = 0;
  String id() => 'e${(_n++).toString().padLeft(4, '0')}';
}

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

void main() {
  final seq = _Seq();

  /// Builds a state whose war-chest balance is [chest] (via a pool contribution).
  HouseholdState stateWithChest(int chest) {
    final events = <Event>[
      PoolContributionMade(
        eventId: seq.id(),
        deviceId: 'd',
        userId: _u1,
        occurredAt: _day(2026, 1, 5),
        createdAt: _day(2026, 1, 5),
        fromUserId: _u1,
        amountCents: chest,
      ),
    ];
    return reduce(events, asOf: _day(2026, 2, 1));
  }

  const config = HomesteadConfig(
    flavorName: 'Homestead',
    stages: [
      HomesteadStage(index: 0, name: 'Bare clearing', thresholdCents: 0, spriteSlot: 'homestead_0.png'),
      HomesteadStage(index: 1, name: 'Tents', thresholdCents: 50000, spriteSlot: 'homestead_1.png'),
      HomesteadStage(index: 2, name: 'Cabin', thresholdCents: 200000, spriteSlot: 'homestead_2.png'),
    ],
  );

  group('buildHomestead', () {
    test('an empty chest sits in the first stage', () {
      final view = buildHomestead(stateWithChest(0), config: config);
      expect(view.stageNumber, 1);
      expect(view.currentStage.name, 'Bare clearing');
      expect(view.nextStage!.name, 'Tents');
      expect(view.centsToNextStage, 50000);
      expect(view.progressToNext, 0.0);
      expect(view.balanceCents, 0);
    });

    test('crossing a threshold advances the stage', () {
      final view = buildHomestead(stateWithChest(60000), config: config);
      expect(view.currentStage.name, 'Tents');
      expect(view.stageNumber, 2);
      expect(view.nextStage!.name, 'Cabin');
      // 60000 sits 10000 into the 50000..200000 band (width 150000).
      expect(view.centsToNextStage, 140000);
      expect(view.progressToNext, closeTo(10000 / 150000, 1e-9));
    });

    test('landing exactly on a threshold enters that stage', () {
      final view = buildHomestead(stateWithChest(200000), config: config);
      expect(view.currentStage.name, 'Cabin');
      expect(view.stageNumber, 3);
      expect(view.nextStage, isNull);
      expect(view.centsToNextStage, isNull);
      expect(view.progressToNext, 1.0);
    });

    test('the final stage reports full progress and no next stage', () {
      final view = buildHomestead(stateWithChest(500000), config: config);
      expect(view.currentStage.name, 'Cabin');
      expect(view.nextStage, isNull);
      expect(view.progressToNext, 1.0);
      expect(view.totalStages, 3);
    });

    test('the flavour name is carried through (renameable)', () {
      const renamed = HomesteadConfig(
        flavorName: 'The Ward',
        stages: [
          HomesteadStage(index: 0, name: 'Empty lot', thresholdCents: 0, spriteSlot: 's0.png'),
          HomesteadStage(index: 1, name: 'Clinic', thresholdCents: 100000, spriteSlot: 's1.png'),
        ],
      );
      final view = buildHomestead(stateWithChest(0), config: renamed);
      expect(view.flavorName, 'The Ward');
      expect(view.currentStage.name, 'Empty lot');
    });

    test('the default config is a valid ascending ladder from zero', () {
      final defaults = HomesteadConfig.defaults();
      expect(defaults.stages.first.thresholdCents, 0);
      for (var i = 1; i < defaults.stages.length; i++) {
        expect(
          defaults.stages[i].thresholdCents,
          greaterThan(defaults.stages[i - 1].thresholdCents),
        );
      }
      // A healthy pool lands somewhere past the first stage without throwing.
      final view = buildHomestead(stateWithChest(75000));
      expect(view.stageNumber, greaterThanOrEqualTo(1));
      expect(view.totalStages, defaults.stages.length);
    });

    test('a negative/clamped chest never falls below the first stage', () {
      // War chest clamps at zero in the reducer; the homestead mirrors that.
      final view = buildHomestead(stateWithChest(0), config: config);
      expect(view.stageNumber, 1);
      expect(view.progressToNext, inInclusiveRange(0.0, 1.0));
    });
  });
}
