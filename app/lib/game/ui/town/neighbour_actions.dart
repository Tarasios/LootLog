/// The two things a visitor can do for a neighbour besides looking: cheer
/// their town (once a day) and send a gift (`gift_dialog.dart`). Shared by
/// the pixel visit and the text tier.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/cheers.dart';
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../hall_common.dart';

/// Whether [meId] already cheered [neighbour] on the day of [now].
bool cheeredToday(GameState game, String meId, TownNeighbour neighbour, DateTime now) =>
    cheered(game, fromId: meId, toId: neighbour.memberId, day: GameDay.fromInstant(now));

/// Cheers [neighbour]'s town through the real command, and says so.
Future<void> cheerNeighbour(
  BuildContext context,
  WidgetRef ref,
  TownNeighbour neighbour,
  NeighbourLines lines,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await runHallCommand(context, ref, (service) => service.cheer(neighbour.memberId));
  if (result == null || !result.accepted) return;
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(lines.line('cheer.sent', {'name': neighbour.name}))));
}
