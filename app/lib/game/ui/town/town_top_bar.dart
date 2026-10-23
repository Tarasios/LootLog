/// The town's top bar: the person's gems, streak and freeze tokens, the
/// shared materials, the text-mode button and the play-mode menu.
library;

import 'package:flutter/material.dart';

import '../../domain/game_state.dart';
import '../hall_status.dart';

class TownTopBar extends StatelessWidget {
  const TownTopBar({
    super.key,
    required this.me,
    required this.hall,
    required this.streak,
    required this.actions,
  });

  final PersonState me;
  final HallState hall;

  /// This person's streak as of today (a stale run reads as empty).
  final LiveStreak streak;

  /// Trailing buttons, built by the shell (text mode, the mode switch).
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final materialsTotal = hall.materials.amounts.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Colors.white),
              child: Row(
                children: [
                  const Icon(Icons.diamond, color: Color(0xFF6DC2CA), size: 18),
                  const SizedBox(width: 4),
                  Text('${me.gems}', key: const ValueKey('town-gems')),
                  const SizedBox(width: 12),
                  const Icon(Icons.local_fire_department, color: Color(0xFFD27D2C), size: 18),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      streak.isEmpty ? 'Start a streak' : '${streak.days}-day streak',
                      key: const ValueKey('town-streak'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.ac_unit, color: Color(0xFF6DC2CA), size: 16),
                  const SizedBox(width: 2),
                  Text('${me.freezeTokens}'),
                  const Spacer(),
                  const Icon(Icons.inventory_2, color: Color(0xFFD2AA99), size: 18),
                  const SizedBox(width: 4),
                  Text('$materialsTotal'),
                  PopupMenuTheme(
                    data: Theme.of(context).popupMenuTheme.copyWith(iconColor: Colors.white),
                    child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
