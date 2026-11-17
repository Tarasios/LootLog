/// How a producer's crew worked since its last collection, beside what it
/// has made on its building sheet: "Full days: the ledger was kept." or the
/// short shifts on quiet days, framed as the town working harder when the
/// ledger is kept.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/hall_rules.dart';
import '../../domain/town/away_summary.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_framed.dart';
import 'town_loop_providers.dart';
import 'town_loop_view.dart';

class ShiftNote extends ConsumerWidget {
  const ShiftNote({
    super.key,
    required this.game,
    required this.personId,
    required this.plotIndex,
    required this.now,
  });

  final GameState game;

  /// Whose town the building stands in (the viewing adult).
  final String personId;
  final int plotIndex;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = producerStretchStart(game.townOf(personId), plotIndex);
    if (start == null || !now.isAfter(start)) return const SizedBox.shrink();
    final lines = ref.watch(townEventLinesProvider).value ?? TownEventLines.defaults;
    final activeDays = game.townActiveDaysOf(personId);
    return Text(
      lines.shiftNote(
        quietDays: quietDaysSince(start, now, activeDays),
        todayLogged: activeDays.contains(GameDay.fromInstant(now)),
      ),
      key: const ValueKey('building-shift-note'),
      style: framedMutedStyle(context),
    );
  }
}
