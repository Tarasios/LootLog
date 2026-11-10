/// The dungeon's framed panels around the battle itself: the sealed gate, the
/// short "the spoils come home" visit when nothing is left to divide, and the
/// victory tally once every weapon is swung. Each shows numbers the battle
/// already holds; none computes money.
library;

import 'package:flutter/material.dart';

import '../../../ui/format.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/pack_sprite.dart';
import '../../battle/month_end_battle.dart';
import '../../domain/game_values.dart';
import '../kit/kit.dart';

/// The widest a framed message gets on a large screen.
const double _kMessageMaxWidth = 520;

/// A ribbon title over a parchment card, centred on the stone, with
/// optional [actions] below — the dungeon's framed message.
class DungeonFramedMessage extends StatelessWidget {
  const DungeonFramedMessage({super.key, required this.title, required this.body, this.actions = const []});

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AdventureTokens.gapLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMessageMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: RibbonTitle(title)),
            const SizedBox(height: AdventureTokens.gap),
            ParchmentCard(padding: const EdgeInsets.all(16), child: body),
            for (final action in actions) ...[const SizedBox(height: AdventureTokens.gap), action],
          ],
        ),
      ),
    ),
  );
}

/// The gate before the month turns: when it opens, in game voice.
class DungeonGateClosed extends StatelessWidget {
  const DungeonGateClosed({super.key, required this.line});

  final String line;

  @override
  Widget build(BuildContext context) => DungeonFramedMessage(
    title: 'Dungeon gate',
    body: Text(line, style: _bodyStyle(context)),
  );
}

/// A finished month with nothing left to divide: the party comes home with
/// the spoils chest anyway.
class SpoilsReturnPanel extends StatelessWidget {
  const SpoilsReturnPanel({
    super.key,
    required this.headline,
    required this.pendingNote,
    required this.saving,
    required this.onReturn,
  });

  final String headline;
  final String? pendingNote;
  final bool saving;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) => DungeonFramedMessage(
    title: 'The spoils',
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: PackSprite(assetKey: GameAssetKeys.chest(ChestType.spoils), scale: 3, label: 'Spoils chest'),
        ),
        const SizedBox(height: AdventureTokens.gapLarge),
        Text(headline, key: const ValueKey('spoils-return'), style: _bodyStyle(context)),
        if (pendingNote case final String note) ...[
          const SizedBox(height: AdventureTokens.gap),
          Text(note, key: const ValueKey('chest-pending'), style: _bodyStyle(context)),
        ],
      ],
    ),
    actions: [WoodButton(label: 'Return to town', expand: true, onPressed: saving ? null : onReturn)],
  );
}

/// Every weapon swung: where the goals and debts stand now, the shared
/// budgets that marched in on their own, and the way home.
class DungeonVictoryPanel extends StatelessWidget {
  const DungeonVictoryPanel({
    super.key,
    required this.battle,
    required this.bosses,
    required this.debts,
    required this.headline,
    required this.pendingNote,
    required this.saving,
    required this.onReturn,
  });

  final MonthEndBattle battle;
  final List<GoalBoss> bosses;
  final List<DebtMonster> debts;
  final String headline;

  /// Shown when the leftovers are saved but the chest has not arrived.
  final String? pendingNote;
  final bool saving;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    final body = _bodyStyle(context);
    // The tally scrolls when long; the way home stays in reach below it.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(child: SingleChildScrollView(child: _tally(context))),
        if (pendingNote case final String note) ...[
          const SizedBox(height: AdventureTokens.gap),
          ParchmentCard(
            child: Text(note, key: const ValueKey('chest-pending'), style: body),
          ),
        ],
        const SizedBox(height: AdventureTokens.gapLarge),
        WoodButton(label: 'Return to town', expand: true, onPressed: saving ? null : onReturn),
      ],
    );
  }

  /// The headline, each goal's fill, each debt, and the shared budgets.
  Widget _tally(BuildContext context) => ParchmentCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(headline, style: AdventureTokens.label(context)),
        for (final boss in bosses) ...[
          const SizedBox(height: AdventureTokens.gap),
          _TallyRow(
            name: boss.name,
            outcome: boss.remainingCents == 0 ? 'Done!' : '${money(boss.remainingCents)} to go',
          ),
          const SizedBox(height: 4),
          MeterBar(fraction: boss.revealFraction, color: AdventureTokens.hpGreen, semanticsLabel: boss.name),
        ],
        for (final debt in debts) ...[
          const SizedBox(height: AdventureTokens.gap),
          _TallyRow(
            name: 'OVERBUDGET on ${debt.name}',
            outcome: debt.outstandingCents == 0 ? 'Cleared!' : '${money(debt.outstandingCents)} left to clear',
          ),
        ],
        if (battle.groupFlows.isNotEmpty) ...[
          const SizedBox(height: AdventureTokens.gapLarge),
          Text('Shared budgets march in on their own', style: AdventureTokens.label(context)),
          for (final flow in battle.groupFlows) ...[
            const SizedBox(height: 4),
            _TallyRow(name: flow.name, outcome: '${money(flow.leftoverCents)} to the war chest'),
          ],
        ],
      ],
    ),
  );
}

/// A name and how it came out, on one line.
class _TallyRow extends StatelessWidget {
  const _TallyRow({required this.name, required this.outcome});

  final String name;
  final String outcome;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(name, style: _bodyStyle(context))),
      const SizedBox(width: AdventureTokens.gap),
      Text(outcome, style: AdventureTokens.amount(context).copyWith(fontSize: 14)),
    ],
  );
}

TextStyle? _bodyStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdventureTokens.ink);
