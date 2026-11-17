/// The Castle on Castle Hill: the long road's last goal, raised once the
/// town is a city in five stages (`Balance.castleStages`: foundation, keep,
/// walls, towers, banners), each a large bill of gems, materials and goods
/// and a build of days.
///
/// Stages go in order, one at a time ([planCastleStage]); the command
/// stores the stage, its cost and its finishing instant in a
/// `CastleStageStarted`. The projection ([applyCastleStage]) keeps the
/// earliest copy of a stage, ignores (and charges nothing for) a stage out
/// of order or begun before the last one finished, and never takes a stage
/// back. A stage finishes on its own at its instant: it adds its prosperity
/// ([castleProsperityAt]) and the reward engine grants its reward once
/// ([castleStageRewardId]); the finished Castle brings a title
/// (`rewards/castle_title.dart`).
///
/// Pure Dart, zero Flutter imports.
library;

import '../../config/balance.dart';
import '../commands/game_commands.dart' show GameRejection;
import '../content.dart';
import '../game_event.dart';
import '../game_state.dart';
import '../game_values.dart';

/// One Castle stage begun.
class CastleStageRecord {
  const CastleStageRecord({required this.key, required this.startedAt, required this.completesAt});

  final String key;
  final DateTime startedAt;
  final DateTime completesAt;

  bool isCompleteAt(DateTime at) => !at.isBefore(completesAt);

  @override
  bool operator ==(Object other) =>
      other is CastleStageRecord &&
      other.key == key &&
      other.startedAt == startedAt &&
      other.completesAt == completesAt;

  @override
  int get hashCode => Object.hash(key, completesAt);
}

/// A town's Castle: the stages begun, in order.
class CastleState {
  const CastleState({this.stages = const []});

  static const CastleState none = CastleState();

  final List<CastleStageRecord> stages;

  int get stagesStarted => stages.length;

  /// How many stages stand finished at [at].
  int stagesCompleteAt(DateTime at) => stages.where((stage) => stage.isCompleteAt(at)).length;

  /// Whether every stage stands finished at [at].
  bool isCompleteAt(DateTime at) => stagesCompleteAt(at) == Balance.castleStages.length;

  @override
  bool operator ==(Object other) =>
      other is CastleState &&
      other.stages.length == stages.length &&
      [for (var i = 0; i < stages.length; i++) other.stages[i] == stages[i]].every((same) => same);

  @override
  int get hashCode => Object.hashAll(stages);
}

/// The spec of 1-based [stage], or null past the last.
CastleStageSpec? castleStageSpec(int stage) =>
    stage >= 1 && stage <= Balance.castleStages.length ? Balance.castleStages[stage - 1] : null;

/// The prosperity [castle]'s finished stages add at [at].
int castleProsperityAt(CastleState castle, DateTime at) {
  var prosperity = 0;
  for (var i = 0; i < castle.stages.length; i++) {
    if (castle.stages[i].isCompleteAt(at)) prosperity += Balance.castleStages[i].prosperity;
  }
  return prosperity;
}

/// Whether [actorId] may begin the next Castle stage now, and which, what
/// it costs and when it finishes.
({GameRejection? rejection, int stage, CastleStageSpec? spec, DateTime? completesAt}) planCastleStage(
    GameState state, String actorId, DateTime now) {
  ({GameRejection? rejection, int stage, CastleStageSpec? spec, DateTime? completesAt}) refuse(
          GameRejection why) =>
      (rejection: why, stage: 0, spec: null, completesAt: null);
  if (state.person(actorId).townTier != TownTier.city) return refuse(GameRejection.townTierTooLow);
  final town = state.townOf(actorId);
  final castle = town.castle;
  if (castle.stages.isNotEmpty && !castle.stages.last.isCompleteAt(now)) {
    return refuse(GameRejection.castleUnderConstruction);
  }
  final stage = castle.stagesStarted + 1;
  final spec = castleStageSpec(stage);
  if (spec == null) return refuse(GameRejection.castleComplete);
  if (state.person(actorId).gems < spec.cost.gems) return refuse(GameRejection.notEnoughGems);
  if (!town.materials.covers(spec.cost.materials)) return refuse(GameRejection.notEnoughMaterials);
  if (!town.goods.stored.covers(spec.goods)) return refuse(GameRejection.notEnoughGoods);
  return (
    rejection: null,
    stage: stage,
    spec: spec,
    completesAt: now.add(Duration(days: spec.buildDays)),
  );
}

/// [town]'s Castle after [started] (paid by the caller), or why it changes
/// nothing: a copy of a stage already begun; a stage out of order (or
/// begun before the last one finished, or one this build lacks); or a stage
/// begun while the town held [tier] below the city, or set to finish before
/// its build days were up.
({CastleState? castle, GameWarningCode? warning}) applyCastleStage(
    HallState town, CastleStageStarted started, {required TownTier tier}) {
  final castle = town.castle;
  if (started.stage >= 1 && started.stage <= castle.stagesStarted) {
    return (castle: null, warning: GameWarningCode.duplicateCastleStage);
  }
  final spec = castleStageSpec(started.stage);
  final previousDone = castle.stages.isEmpty || castle.stages.last.isCompleteAt(started.occurredAt);
  if (spec == null ||
      spec.key != started.stageKey ||
      started.stage != castle.stagesStarted + 1 ||
      !previousDone) {
    return (castle: null, warning: GameWarningCode.castleOutOfOrder);
  }
  final earliestFinish = started.occurredAt.add(Duration(days: spec.buildDays));
  if (tier != TownTier.city || started.completesAt.isBefore(earliestFinish)) {
    return (castle: null, warning: GameWarningCode.castleStageInvalid);
  }
  return (
    castle: CastleState(
      stages: List.unmodifiable([
        ...castle.stages,
        CastleStageRecord(key: spec.key, startedAt: started.occurredAt, completesAt: started.completesAt),
      ]),
    ),
    warning: null,
  );
}

/// The reward id of [who]'s reward for finishing Castle stage [stageKey]:
/// one per person per stage.
String castleStageRewardId(String who, String stageKey) => 'castle:$who:$stageKey';

/// What finishing each stage brings: gems, and for the last stage (the
/// banners) a trophy for the mantel too.
Loot castleStageReward(int stage) => Loot(
      gems: Balance.castleStageRewardGems,
      materials: stage == Balance.castleStages.length
          ? MaterialBundle({MaterialKind.trophy: 1})
          : const MaterialBundle.empty(),
    );
