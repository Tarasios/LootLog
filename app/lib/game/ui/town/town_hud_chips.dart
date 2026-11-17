/// The town HUD's chips: the date (which opens the town book), the town
/// spirit, the streak and freeze tokens on the left; gems, the gold pouch
/// and the war chest on the right.
library;

import 'package:flutter/material.dart';

import '../../../domain/money.dart';
import '../../../ui/format.dart';
import '../hall_status.dart';
import '../kit/kit.dart';

/// The figures the HUD shows. Money is null until the ledger loads.
class TownHudFigures {
  const TownHudFigures({
    required this.dateLabel,
    required this.streak,
    required this.freezeTokens,
    required this.gems,
    required this.inboxCount,
    this.goldPouch,
    this.warChest,
  });

  /// "Oct · day 3".
  final String dateLabel;
  final LiveStreak streak;
  final int freezeTokens;
  final int gems;

  /// Unopened chests plus unclaimed rewards.
  final int inboxCount;
  final Money? goldPouch;
  final Money? warChest;
}

/// The date, the town spirit, the streak and the freeze tokens, each at most
/// [maxWidth] wide.
List<Widget> townTimeChips(
  TownHudFigures figures, {
  required double maxWidth,
  Widget? spiritBar,
  VoidCallback? onDate,
}) => [
  HudChip(
    key: const ValueKey('town-hud-date'),
    icon: Icons.calendar_today,
    value: figures.dateLabel,
    maxWidth: maxWidth,
    onTap: onDate,
  ),
  ?spiritBar,
  HudChip(
    icon: Icons.local_fire_department,
    color: AdventureTokens.hpRed,
    value: figures.streak.isEmpty ? 'Start a streak' : '${figures.streak.days}-day streak',
    valueKey: const ValueKey('town-streak'),
    maxWidth: maxWidth,
  ),
  HudChip(
    icon: Icons.ac_unit,
    color: AdventureTokens.gem,
    value: '${figures.freezeTokens}',
    valueKey: const ValueKey('town-freeze-tokens'),
    maxWidth: maxWidth,
  ),
];

/// Gems and, once the ledger loads, the gold pouch and the war chest
/// (named only on a wide window).
List<Widget> townTreasureChips(TownHudFigures figures, {required bool compact, required double maxWidth}) {
  final goldPouch = figures.goldPouch;
  final warChest = figures.warChest;
  return [
    HudChip(
      icon: Icons.diamond,
      color: AdventureTokens.gem,
      value: '${figures.gems}',
      valueKey: const ValueKey('town-gems'),
      maxWidth: maxWidth,
    ),
    if (goldPouch != null)
      HudChip(
        icon: Icons.savings,
        color: AdventureTokens.gold,
        value: money(goldPouch.cents),
        label: compact ? null : 'gold pouch',
        valueKey: const ValueKey('town-gold-pouch'),
        maxWidth: maxWidth,
      ),
    if (warChest != null)
      HudChip(
        icon: Icons.account_balance,
        color: AdventureTokens.chest,
        value: money(warChest.cents),
        label: compact ? null : 'war chest',
        valueKey: const ValueKey('town-war-chest'),
        maxWidth: maxWidth,
      ),
  ];
}
