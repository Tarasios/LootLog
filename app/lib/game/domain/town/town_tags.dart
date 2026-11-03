/// The small floating tags over the town: leftovers waiting at the gate,
/// bills coming due, goal progress, a chest to open, a building ready to
/// upgrade. Only actionable or encouraging news gets a tag, and each spot
/// carries at most one (the urgent one first). The wording comes from
/// `assets/game/text/town_tags.json` ([TownTagLines]); every number is
/// handed in from existing read models. Pure Dart, zero Flutter imports.
library;

import 'quest_board_view.dart';
import 'town_view.dart';

/// Where a tag floats.
sealed class TownTagAnchor {
  const TownTagAnchor();
}

class PlotAnchor extends TownTagAnchor {
  const PlotAnchor(this.plotIndex);
  final int plotIndex;

  @override
  bool operator ==(Object other) => other is PlotAnchor && other.plotIndex == plotIndex;

  @override
  int get hashCode => Object.hash(PlotAnchor, plotIndex);

  @override
  String toString() => 'PlotAnchor($plotIndex)';
}

class HouseAnchor extends TownTagAnchor {
  const HouseAnchor(this.personId);
  final String personId;

  @override
  bool operator ==(Object other) => other is HouseAnchor && other.personId == personId;

  @override
  int get hashCode => Object.hash(HouseAnchor, personId);

  @override
  String toString() => 'HouseAnchor($personId)';
}

class GateAnchor extends TownTagAnchor {
  const GateAnchor();

  @override
  bool operator ==(Object other) => other is GateAnchor;

  @override
  int get hashCode => (GateAnchor).hashCode;

  @override
  String toString() => 'GateAnchor()';
}

class StatueAnchor extends TownTagAnchor {
  const StatueAnchor(this.questId);
  final String questId;

  @override
  bool operator ==(Object other) => other is StatueAnchor && other.questId == questId;

  @override
  int get hashCode => Object.hash(StatueAnchor, questId);

  @override
  String toString() => 'StatueAnchor($questId)';
}

class TownTag {
  const TownTag({required this.anchor, required this.text, this.urgent = false});

  final TownTagAnchor anchor;
  final String text;

  /// Time-sensitive (leftovers to divide, a bill due today or tomorrow):
  /// drawn more prominently, never as a warning or a scolding.
  final bool urgent;

  @override
  bool operator ==(Object other) =>
      other is TownTag && other.anchor == anchor && other.text == text && other.urgent == urgent;

  @override
  int get hashCode => Object.hash(anchor, text, urgent);

  @override
  String toString() => 'TownTag($anchor, "$text"${urgent ? ', urgent' : ''})';
}

/// The tags' wording, with `{placeholders}` filled by [townTags].
class TownTagLines {
  const TownTagLines({
    required this.toDivide,
    required this.billDue,
    required this.billDueToday,
    required this.goalProgress,
    required this.chestWaiting,
    required this.upgradeReady,
  });

  /// The built-in lines, used before the file loads and for any key it lacks.
  static const TownTagLines defaults = TownTagLines(
    toDivide: '{count} to divide',
    billDue: '{name} in {days}d',
    billDueToday: '{name} today',
    goalProgress: '{name} {percent}%',
    chestWaiting: 'Chest waiting',
    upgradeReady: 'Ready to upgrade',
  );

  /// Reads `town_tags.json`; a missing, empty or non-text key keeps its
  /// built-in line, so a half-edited file never blanks a tag.
  factory TownTagLines.fromJson(Map<String, dynamic> json) {
    String line(String key, String fallback) {
      final value = json[key];
      return value is String && value.trim().isNotEmpty ? value : fallback;
    }

    return TownTagLines(
      toDivide: line('toDivide', defaults.toDivide),
      billDue: line('billDue', defaults.billDue),
      billDueToday: line('billDueToday', defaults.billDueToday),
      goalProgress: line('goalProgress', defaults.goalProgress),
      chestWaiting: line('chestWaiting', defaults.chestWaiting),
      upgradeReady: line('upgradeReady', defaults.upgradeReady),
    );
  }

  /// `{count}`: how many leftovers wait to be divided.
  final String toDivide;

  /// `{name}`, `{days}`: a bill due in one to three days.
  final String billDue;

  /// `{name}`: a bill due today.
  final String billDueToday;

  /// `{name}`, `{percent}`: a goal's progress.
  final String goalProgress;
  final String chestWaiting;
  final String upgradeReady;

  @override
  bool operator ==(Object other) =>
      other is TownTagLines &&
      other.toDivide == toDivide &&
      other.billDue == billDue &&
      other.billDueToday == billDueToday &&
      other.goalProgress == goalProgress &&
      other.chestWaiting == chestWaiting &&
      other.upgradeReady == upgradeReady;

  @override
  int get hashCode => Object.hash(toDivide, billDue, billDueToday, goalProgress, chestWaiting, upgradeReady);
}

/// A recurring bill as the tags need it: [ownerId] is the adult whose
/// personal bill it is, or null for a shared one.
typedef TownBill = ({String name, int daysUntilDue, String? ownerId});

/// Bills further out than this many days get no tag.
const int kTownBillTagDays = 3;

/// The Central Hall's plot, where household-wide tags float.
const int kCentralHallPlotIndex = 0;

/// The town's tags, urgent ones first. Each anchor carries at most one: an
/// urgent tag wins, otherwise the first in this order — leftovers to divide
/// (the gate), bills soonest first (the owner's house, or the Central Hall
/// for a shared bill or an owner without a house), a waiting chest (the
/// Central Hall), buildings in [upgradeReadyPlots] (the caller checks the
/// build rules), then goal progress (a goal's statue, for the goals furthest
/// along that have any progress, one per statue spot).
List<TownTag> townTags({
  required TownView view,
  required QuestBoardView board,
  required int leftoversToDivide,
  required List<TownBill> upcomingBills,
  required int unopenedChests,
  required TownTagLines lines,
  Set<int> upgradeReadyPlots = const {},
}) {
  final candidates = <TownTag>[];
  const hall = PlotAnchor(kCentralHallPlotIndex);

  if (leftoversToDivide > 0) {
    candidates.add(TownTag(
      anchor: const GateAnchor(),
      text: _fill(lines.toDivide, {'count': '$leftoversToDivide'}),
      urgent: true,
    ));
  }

  final residents = {for (final resident in view.residents) resident.personId};
  final dueSoon = [
    for (final bill in upcomingBills)
      if (bill.daysUntilDue >= 0 && bill.daysUntilDue <= kTownBillTagDays) bill,
  ]..sort((first, second) => first.daysUntilDue.compareTo(second.daysUntilDue));
  for (final bill in dueSoon) {
    final owner = bill.ownerId;
    candidates.add(TownTag(
      anchor: owner != null && residents.contains(owner) ? HouseAnchor(owner) : hall,
      text: bill.daysUntilDue == 0
          ? _fill(lines.billDueToday, {'name': bill.name})
          : _fill(lines.billDue, {'name': bill.name, 'days': '${bill.daysUntilDue}'}),
      urgent: bill.daysUntilDue <= 1,
    ));
  }

  if (unopenedChests > 0) {
    candidates.add(TownTag(anchor: hall, text: lines.chestWaiting));
  }

  for (final plot in view.plots) {
    if (plot.unlocked && upgradeReadyPlots.contains(plot.plotIndex)) {
      candidates.add(TownTag(anchor: PlotAnchor(plot.plotIndex), text: lines.upgradeReady));
    }
  }

  final goalsWithProgress = [
    for (final goal in board.goals)
      if (goal.percent > 0) goal,
  ]..sort((first, second) => second.percent.compareTo(first.percent));
  for (final goal in goalsWithProgress.take(view.layout.statueSpots.length)) {
    candidates.add(TownTag(
      anchor: StatueAnchor(goal.questId),
      text: _fill(lines.goalProgress, {'name': goal.name, 'percent': '${goal.percent}'}),
    ));
  }

  // Urgent first; the stable sort keeps the priority order within each.
  final ordered = [
    ...candidates.where((tag) => tag.urgent),
    ...candidates.where((tag) => !tag.urgent),
  ];
  final taken = <TownTagAnchor>{};
  return List.unmodifiable([
    for (final tag in ordered)
      if (taken.add(tag.anchor)) tag,
  ]);
}

String _fill(String template, Map<String, String> values) {
  var text = template;
  values.forEach((placeholder, value) => text = text.replaceAll('{$placeholder}', value));
  return text;
}
