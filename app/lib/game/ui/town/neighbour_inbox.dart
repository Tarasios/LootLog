/// The neighbours in the inbox: the cheers this adult's town received this
/// week ("Sam cheered your town"), and the wording of a trade-road caravan,
/// which names the goods and where they came from in positive terms only (a
/// Standard adult's supply caravan is never named).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/cheers.dart';
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/trade_road.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import 'neighbour_providers.dart';

/// How far back the inbox lists cheers.
const int kCheerInboxDays = 7;

/// The inbox title of trade-road reward [rewardId] carrying [loot]: from a
/// named Adventure neighbour's town, or from the (unnamed) supply caravan.
String tradeRoadInboxTitle(String rewardId, Loot loot, HallLedgerView view, NeighbourLines lines) {
  final goods = HallNames.loot(loot);
  final fromId = tradeRoadNeighbourOf(rewardId);
  final from = view.adults.where((adult) => adult.memberId == fromId).firstOrNull;
  if (from == null || !from.inAdventure) return lines.line('trade.fromCaravan', {'goods': goods});
  return lines.line('trade.fromTown', {'name': from.name, 'goods': goods});
}

/// The cheers [view]'s adult received in the last [kCheerInboxDays] days;
/// nothing at all when there are none.
class NeighbourCheers extends ConsumerWidget {
  const NeighbourCheers({super.key, required this.game, required this.view, required this.now});

  final GameState game;
  final HallLedgerView view;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lines = ref.watch(neighbourLinesProvider).value ?? NeighbourLines.defaults;
    final since = GameDay.fromInstant(now).addDays(-(kCheerInboxDays - 1));
    final cheers = cheersFor(game, view.meId ?? '', since: since);
    if (cheers.isEmpty) return const SizedBox.shrink();
    String nameOf(String memberId) =>
        view.adults.where((adult) => adult.memberId == memberId).firstOrNull?.name ?? 'A neighbour';
    return FramedSection(
      title: lines.line('cheer.section'),
      icon: Icons.celebration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final cheer in cheers)
            Text(lines.line('cheer.received', {'name': nameOf(cheer.fromId)}), style: framedBodyStyle(context)),
        ],
      ),
    );
  }
}
