/// Riverpod wiring for the town's growth: the writers' file of growth lines
/// (`town_growth.json`): tier names and celebrations, districts, farm
/// buildings and the town book.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/town/town_growth_lines.dart';

/// The writers' file of town growth wording.
const String kTownGrowthAsset = 'assets/game/text/town_growth.json';

/// The town's growth lines, loaded once. Screens use
/// `.value ?? TownGrowthLines.defaults`.
final townGrowthLinesProvider = FutureProvider<TownGrowthLines>((ref) async {
  final text = await rootBundle.loadString(kTownGrowthAsset);
  return TownGrowthLines.fromJson(jsonDecode(text) as Map<String, dynamic>);
});

