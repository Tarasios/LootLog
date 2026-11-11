/// Riverpod wiring for the road between neighbouring towns: the writers'
/// file of neighbourly lines (`neighbours.json`) and the neighbours of this
/// device's adult.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../../domain/town/town_view.dart' show TownAdult;
import '../hall_ledger_view.dart';

/// The writers' file of neighbourly wording.
const String kNeighbourLinesAsset = 'assets/game/text/neighbours.json';

/// The neighbourly lines, loaded once. Screens use
/// `.value ?? NeighbourLines.defaults`.
final neighbourLinesProvider = FutureProvider<NeighbourLines>((ref) async {
  final text = await rootBundle.loadString(kNeighbourLinesAsset);
  return NeighbourLines.fromJson(jsonDecode(text) as Map<String, dynamic>);
});

/// The household's adults as the town needs them.
List<TownAdult> townAdults(HallLedgerView view) => [
  for (final adult in view.adults)
    TownAdult(memberId: adult.memberId, name: adult.name, inAdventure: adult.inAdventure),
];

/// The neighbours of this device's adult in [game].
List<TownNeighbour> myNeighbours(GameState game, HallLedgerView view) =>
    neighboursOf(game, view.meId ?? '', townAdults(view));
