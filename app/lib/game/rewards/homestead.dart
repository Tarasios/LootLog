/// The Homestead — meta-progression, pure visualization only.
///
/// The war chest (the household's long-term shared pool) is shown as something
/// being built up outside the dungeon: by default a homestead that gains visible
/// stages as the *real* pool balance crosses configurable thresholds. The
/// flavour is renameable (a town, a ward being cared for, …) and the ladder is
/// configurable, but nothing here gates or modifies a single cent — it reads
/// [HouseholdState.warChest] and maps it to a stage and a progress bar.
///
/// Text-mode is the first-class rendering; each stage also carries a
/// [HomesteadStage.spriteSlot] so pixel art can slot in later without touching
/// this logic. Pure Dart, Flutter-free, unit-tested like the domain.
library;

import '../../domain/state.dart';

/// One build stage of the homestead, shown once the pool reaches
/// [thresholdCents]. [spriteSlot] is the asset name a pixel-art tier will use.
class HomesteadStage {
  const HomesteadStage({
    required this.index,
    required this.name,
    required this.thresholdCents,
    required this.spriteSlot,
  });

  final int index;
  final String name;
  final int thresholdCents;
  final String spriteSlot;

  @override
  bool operator ==(Object other) =>
      other is HomesteadStage &&
      other.index == index &&
      other.name == name &&
      other.thresholdCents == thresholdCents &&
      other.spriteSlot == spriteSlot;

  @override
  int get hashCode => Object.hash(index, name, thresholdCents, spriteSlot);
}

/// The configurable homestead ladder plus its renameable flavour label. Stages
/// must be sorted ascending by threshold with the first stage at 0.
class HomesteadConfig {
  const HomesteadConfig({required this.flavorName, required this.stages});

  /// The default ladder: a homestead built up in six stages. Thresholds are in
  /// integer cents ($0 → $250). Callers may substitute their own flavour and
  /// thresholds (a town, a ward, …) via a cosmetic setting.
  factory HomesteadConfig.defaults() => const HomesteadConfig(
        flavorName: 'Homestead',
        stages: [
          HomesteadStage(
              index: 0,
              name: 'Bare clearing',
              thresholdCents: 0,
              spriteSlot: 'homestead_stage_0.png'),
          HomesteadStage(
              index: 1,
              name: 'Tents pitched',
              thresholdCents: 50000,
              spriteSlot: 'homestead_stage_1.png'),
          HomesteadStage(
              index: 2,
              name: 'Log cabin',
              thresholdCents: 200000,
              spriteSlot: 'homestead_stage_2.png'),
          HomesteadStage(
              index: 3,
              name: 'Farmhouse & fields',
              thresholdCents: 500000,
              spriteSlot: 'homestead_stage_3.png'),
          HomesteadStage(
              index: 4,
              name: 'Thriving homestead',
              thresholdCents: 1000000,
              spriteSlot: 'homestead_stage_4.png'),
          HomesteadStage(
              index: 5,
              name: 'Grand estate',
              thresholdCents: 2500000,
              spriteSlot: 'homestead_stage_5.png'),
        ],
      );

  final String flavorName;
  final List<HomesteadStage> stages;
}

/// The read-time homestead view: where the pool balance currently sits on the
/// ladder and how far it is to the next stage. Pure visualization of a real
/// number — no money is gated or changed.
class HomesteadView {
  const HomesteadView({
    required this.flavorName,
    required this.balanceCents,
    required this.currentStage,
    required this.nextStage,
    required this.centsToNextStage,
    required this.progressToNext,
    required this.stageNumber,
    required this.totalStages,
  });

  final String flavorName;
  final int balanceCents;
  final HomesteadStage currentStage;

  /// The next stage up, or null when the pool is already at the top stage.
  final HomesteadStage? nextStage;

  /// Cents still needed to reach [nextStage], or null at the top stage.
  final int? centsToNextStage;

  /// Progress through the current stage's band toward the next, in `0.0..1.0`
  /// (1.0 at the top stage).
  final double progressToNext;

  /// 1-based index of the current stage for display ("Stage 2 of 6").
  final int stageNumber;
  final int totalStages;

  bool get atTopStage => nextStage == null;
}

/// Builds the [HomesteadView] for the current war-chest balance. [config]
/// defaults to [HomesteadConfig.defaults].
HomesteadView buildHomestead(HouseholdState state, {HomesteadConfig? config}) {
  final cfg = config ?? HomesteadConfig.defaults();
  final stages = cfg.stages;
  assert(stages.isNotEmpty, 'homestead needs at least one stage');

  // The reducer clamps the war chest at zero; mirror that so a stage is always
  // resolvable.
  final balance = state.warChest.balanceCents < 0
      ? 0
      : state.warChest.balanceCents;

  // The current stage is the highest whose threshold the balance has reached.
  var currentIndex = 0;
  for (var i = 0; i < stages.length; i++) {
    if (balance >= stages[i].thresholdCents) {
      currentIndex = i;
    } else {
      break;
    }
  }

  final current = stages[currentIndex];
  final next =
      currentIndex + 1 < stages.length ? stages[currentIndex + 1] : null;

  int? centsToNext;
  double progress;
  if (next == null) {
    centsToNext = null;
    progress = 1.0;
  } else {
    centsToNext = next.thresholdCents - balance;
    if (centsToNext < 0) centsToNext = 0;
    final band = next.thresholdCents - current.thresholdCents;
    progress = band <= 0 ? 1.0 : (balance - current.thresholdCents) / band;
    if (progress < 0.0) progress = 0.0;
    if (progress > 1.0) progress = 1.0;
  }

  return HomesteadView(
    flavorName: cfg.flavorName,
    balanceCents: balance,
    currentStage: current,
    nextStage: next,
    centsToNextStage: centsToNext,
    progressToNext: progress,
    stageNumber: currentIndex + 1,
    totalStages: stages.length,
  );
}
