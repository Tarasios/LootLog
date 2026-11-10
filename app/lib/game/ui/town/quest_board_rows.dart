/// The rows of the town's quest board: a goal boss with its HP bar, an
/// OVERBUDGET to clear, this month's category monsters and a recent purchase,
/// each on a parchment card, plus the small section heading over them.
///
/// Money is formatted with `ui/format.dart`; every figure comes straight from
/// [QuestBoardView]. The wording stays supportive: an overspent category is
/// "enraged", never a failure.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../ui/format.dart';
import '../../assets/asset_key.dart';
import '../../assets/pack_sprite.dart';
import '../../domain/town/quest_board_view.dart';
import '../kit/kit.dart';

/// The goal boss drawn when a goal has no picture of its own.
const AssetKey kGoalBossKey = AssetKey('boss', 'goal');

/// The OVERBUDGET monster.
const AssetKey kOverbudgetKey = AssetKey('boss', 'overbudget');

/// The portrait size beside a goal or a debt.
const double _kPortraitSize = 32;

/// A section heading on the wood: pixel label in parchment.
class QuestBoardHeading extends StatelessWidget {
  const QuestBoardHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, AdventureTokens.gap, 4, 4),
    child: Text(
      text,
      style: AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment),
    ),
  );
}

/// A tappable parchment card with the board's compact padding.
class _BoardCard extends StatelessWidget {
  const _BoardCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: ParchmentCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      onTap: onTap,
      child: child,
    ),
  );
}

/// A one-line pixel label that ellipsizes.
Text _name(BuildContext context, String text) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AdventureTokens.label(context),
);

/// A figure in the legible money face, muted.
Text _figure(BuildContext context, String text, {Color? color}) => Text(
  text,
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  style: AdventureTokens.amount(context).copyWith(
    fontSize: 14,
    color: color ?? AdventureTokens.inkMuted,
  ),
);

/// A goal boss: its picture (once decoded) or the default boss, its name and
/// percent, an HP bar of progress and what is still to go.
class GoalRow extends StatelessWidget {
  const GoalRow({super.key, required this.goal, this.picture, this.onTap});

  final QuestBoardGoal goal;
  final ui.Image? picture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final picture = this.picture;
    return _BoardCard(
      onTap: onTap,
      child: Row(
        children: [
          SizedBox.square(
            dimension: _kPortraitSize,
            child: picture != null
                ? RawImage(image: picture, fit: BoxFit.contain, filterQuality: FilterQuality.none)
                : PackSprite(assetKey: kGoalBossKey, label: 'Goal'),
          ),
          const SizedBox(width: AdventureTokens.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _name(context, goal.name)),
                    const SizedBox(width: 6),
                    _figure(context, '${goal.percent}%', color: AdventureTokens.ink),
                  ],
                ),
                const SizedBox(height: 3),
                MeterBar(
                  fraction: goal.percent / 100,
                  color: AdventureTokens.hpGreen,
                  semanticsLabel: '${goal.name} progress',
                ),
                const SizedBox(height: 3),
                _figure(context, '${money(goal.remaining.cents)} to go'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// An OVERBUDGET still to clear: leftovers fell it at month end.
class DebtRow extends StatelessWidget {
  const DebtRow({super.key, required this.debt, this.onTap});

  final QuestBoardDebt debt;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => _BoardCard(
    onTap: onTap,
    child: Row(
      children: [
        SizedBox.square(
          dimension: _kPortraitSize,
          child: PackSprite(assetKey: kOverbudgetKey, label: 'Debt'),
        ),
        const SizedBox(width: AdventureTokens.gap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _name(context, debt.name),
              _figure(context, '${money(debt.outstanding.cents)} to clear'),
            ],
          ),
        ),
      ],
    ),
  );
}

/// One category this month: its colour, name, what is left (or how far it
/// went over, enraged) and an HP bar of what remains of its limit.
class MonsterRow extends StatelessWidget {
  const MonsterRow({super.key, required this.monster, this.onTap});

  final QuestBoardMonster monster;
  final VoidCallback? onTap;

  /// What remains of the limit, 0..1 (a zero limit reads as empty).
  double get remainingFraction => monster.limit.cents <= 0
      ? 0
      : (monster.remaining.cents / monster.limit.cents).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final enraged = monster.enraged;
    final status = enraged
        ? 'enraged · ${money(monster.overspend.cents)} over'
        : '${money(monster.remaining.cents)} left';
    return _BoardCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(monster.colorArgb),
                  border: Border.all(color: AdventureTokens.woodDark),
                ),
                child: const SizedBox.square(dimension: 10),
              ),
              const SizedBox(width: 6),
              Expanded(child: _name(context, monster.name)),
              const SizedBox(width: 6),
              Flexible(
                child: _figure(
                  context,
                  status,
                  color: enraged ? AdventureTokens.hpRed : AdventureTokens.inkMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MeterBar(
            fraction: remainingFraction,
            color: enraged ? AdventureTokens.hpRed : AdventureTokens.hpGreen,
            height: 8,
            semanticsLabel: '${monster.name} left this month',
          ),
        ],
      ),
    );
  }
}

/// A short line of text on a card: the writs waiting, an invitation.
class NoteRow extends StatelessWidget {
  const NoteRow({super.key, required this.text, this.icon, this.onTap});

  final String text;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return _BoardCard(
      onTap: onTap,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AdventureTokens.inkMuted),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(text, style: AdventureTokens.label(context)),
          ),
        ],
      ),
    );
  }
}

/// The recent purchases on one card: what, and how much.
class RecentLootCard extends StatelessWidget {
  const RecentLootCard({super.key, required this.entries});

  final List<QuestBoardEntry> entries;

  @override
  Widget build(BuildContext context) => _BoardCard(
    child: Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: _name(context, entry.label)),
                const SizedBox(width: 6),
                _figure(context, money(entry.amount.cents), color: AdventureTokens.ink),
              ],
            ),
          ),
      ],
    ),
  );
}
