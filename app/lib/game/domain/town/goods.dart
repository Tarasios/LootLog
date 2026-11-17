/// Refined goods: planks, cut stone, tools and cloth, made in Market Row
/// workshops from raw materials, and wanted by the top civic tiers and every
/// Castle stage.
///
/// A job is started with [planStartRefining]: the command settles the
/// batches, what goes in, what comes out and when it is done, and stores
/// them all in a `RefiningStarted` (the job's id is that event's id). A
/// workshop holds one job until it is collected; collecting
/// ([planCollectGoods]) credits the job's stored output, once. The
/// projection's appliers ([applyRefiningStarted], [applyGoodsCollected])
/// make both convergent: the earliest start on a workshop stands, a second
/// one (another device's) is ignored and charged nothing, and a second
/// collect of the same job credits nothing.
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../commands/game_commands.dart' show GameRejection;
import '../content.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';
import 'districts.dart';

/// One workshop job: started, stored, waiting to be collected.
class RefiningJob {
  const RefiningJob({
    required this.jobId,
    required this.recipeId,
    required this.batches,
    required this.output,
    required this.startedAt,
    required this.completesAt,
  });

  /// The `RefiningStarted` event's id.
  final String jobId;
  final String recipeId;
  final int batches;
  final GoodsBundle output;
  final DateTime startedAt;
  final DateTime completesAt;

  bool isDoneAt(DateTime at) => !at.isBefore(completesAt);

  @override
  bool operator ==(Object other) =>
      other is RefiningJob &&
      other.jobId == jobId &&
      other.recipeId == recipeId &&
      other.batches == batches &&
      other.output == output &&
      other.startedAt == startedAt &&
      other.completesAt == completesAt;

  @override
  int get hashCode => Object.hash(jobId, completesAt);
}

/// A town's goods: what is stored and each workshop's job.
class TownGoods {
  const TownGoods({this.stored = const GoodsBundle.empty(), this.jobs = const {}});

  static const TownGoods empty = TownGoods();

  /// Goods in store (uncapped: goods are kept in the workshops' lofts).
  final GoodsBundle stored;

  /// The job each busy workshop holds, by its plot.
  final Map<PlotAddress, RefiningJob> jobs;

  TownGoods copyWith({GoodsBundle? stored, Map<PlotAddress, RefiningJob>? jobs}) =>
      TownGoods(stored: stored ?? this.stored, jobs: jobs ?? this.jobs);

  @override
  bool operator ==(Object other) =>
      other is TownGoods &&
      other.stored == stored &&
      other.jobs.length == jobs.length &&
      jobs.entries.every((entry) => other.jobs[entry.key] == entry.value);

  @override
  int get hashCode => Object.hash(stored, jobs.length);
}

/// The recipe [recipeId], or null for one this build lacks.
RefiningRecipe? refiningRecipe(String recipeId) => Balance.refiningRecipes[recipeId];

/// The most batches a workshop of [tier] takes in one job.
int workshopMaxBatches(int tier) =>
    Balance.workshopMaxBatchesByTier[tier.clamp(0, Balance.workshopMaxBatchesByTier.length - 1)];

/// [town]'s workshops in service at [at], best tier first (then by plot).
List<({PlotAddress address, int tier})> workshopsAt(HallState town, DateTime at) {
  final workshops = [
    for (final entry in town.districts.buildings.entries)
      if (entry.value.civicType == CivicBuildingType.workshop && entry.value.tierAt(at) >= 1)
        (address: entry.key, tier: entry.value.tierAt(at)),
  ]..sort((first, second) => first.tier != second.tier
      ? second.tier.compareTo(first.tier)
      : first.address.plotIndex.compareTo(second.address.plotIndex));
  return workshops;
}

/// Whether [actorId] may refine [batches] batches of [recipeId] now, and
/// the workshop, what goes in, what comes out and when it is done. The job
/// goes to the best idle workshop.
({GameRejection? rejection, PlotAddress? workshop, MaterialBundle input, GoodsBundle output, DateTime? completesAt})
    planStartRefining(GameState state, String actorId, String recipeId, int batches, DateTime now) {
  ({GameRejection? rejection, PlotAddress? workshop, MaterialBundle input, GoodsBundle output, DateTime? completesAt})
      refuse(GameRejection why) => (
            rejection: why,
            workshop: null,
            input: const MaterialBundle.empty(),
            output: const GoodsBundle.empty(),
            completesAt: null,
          );
  final town = state.townOf(actorId);
  final workshops = workshopsAt(town, now);
  if (workshops.isEmpty) return refuse(GameRejection.noWorkshop);
  final recipe = refiningRecipe(recipeId);
  if (recipe == null) return refuse(GameRejection.unknownRecipe);
  final idle = [
    for (final workshop in workshops)
      if (!town.goods.jobs.containsKey(workshop.address)) workshop,
  ];
  if (idle.isEmpty) return refuse(GameRejection.workshopBusy);
  final workshop = idle.first;
  if (batches < 1 || batches > workshopMaxBatches(workshop.tier)) {
    return refuse(GameRejection.invalidBatches);
  }
  final input = recipe.input.scaled(batches);
  if (!town.materials.covers(input)) return refuse(GameRejection.notEnoughMaterials);
  return (
    rejection: null,
    workshop: workshop.address,
    input: input,
    output: GoodsBundle({recipe.output: recipe.outputPerBatch * batches}),
    completesAt: now.add(Duration(minutes: recipe.minutesPerBatch * batches)),
  );
}

/// The jobs [actorId] can collect now (done by [now]), in plot order, or
/// why nothing.
({GameRejection? rejection, List<({PlotAddress address, RefiningJob job})> done}) planCollectGoods(
    GameState state, String actorId, DateTime now) {
  final jobs = state.townOf(actorId).goods.jobs;
  final done = [
    for (final entry in jobs.entries)
      if (entry.value.isDoneAt(now)) (address: entry.key, job: entry.value),
  ]..sort((first, second) => first.address.plotIndex.compareTo(second.address.plotIndex));
  return (rejection: done.isEmpty ? GameRejection.nothingToCollect : null, done: done);
}

/// [town]'s goods after [started] (the input is charged by the caller), or
/// why it changes nothing: a recipe this build lacks, no workshop in
/// service on that plot, or a workshop already busy (the earlier start
/// stands).
({TownGoods? goods, GameWarningCode? warning}) applyRefiningStarted(
    HallState town, RefiningStarted started) {
  if (refiningRecipe(started.recipeId) == null) {
    return (goods: null, warning: GameWarningCode.unknownRecipe);
  }
  final address = PlotAddress(started.districtId, started.plotIndex);
  final building = town.districts.buildingAt(address);
  if (building?.civicType != CivicBuildingType.workshop || building!.tierAt(started.occurredAt) < 1) {
    return (goods: null, warning: GameWarningCode.unknownBuilding);
  }
  if (town.goods.jobs.containsKey(address)) {
    return (goods: null, warning: GameWarningCode.workshopBusy);
  }
  return (
    goods: town.goods.copyWith(
      jobs: Map.unmodifiable({
        ...town.goods.jobs,
        address: RefiningJob(
          jobId: started.eventId,
          recipeId: started.recipeId,
          batches: started.batches,
          output: started.output,
          startedAt: started.occurredAt,
          completesAt: started.completesAt,
        ),
      }),
    ),
    warning: null,
  );
}

/// [town]'s goods after [collected]: the job's stored output credited and
/// the workshop freed, or a warning when no such job waits done (already
/// collected, typically on another device, or not finished yet).
({TownGoods? goods, GameWarningCode? warning}) applyGoodsCollected(
    HallState town, GoodsCollected collected) {
  final address = PlotAddress(collected.districtId, collected.plotIndex);
  final job = town.goods.jobs[address];
  if (job == null || job.jobId != collected.jobId || !job.isDoneAt(collected.occurredAt)) {
    return (goods: null, warning: GameWarningCode.unknownJob);
  }
  return (
    goods: TownGoods(
      stored: town.goods.stored + job.output,
      jobs: Map.unmodifiable({...town.goods.jobs}..remove(address)),
    ),
    warning: null,
  );
}
