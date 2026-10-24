/// One turn of the month-end battle: where a category's leftover goes. Every
/// number shown is the shared move module's preview (the reducer's own
/// math); this sheet only returns the chosen [SpoilsChoice].
library;

import 'package:flutter/material.dart';

import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../../ui/format.dart';
import '../../../ui/glossary.dart';
import '../../battle/month_end_battle.dart';

Future<SpoilsChoice?> showBattleTurnSheet(
  BuildContext context, {
  required BattleWeapon weapon,
  required List<GoalBoss> bosses,
  required List<DebtMonster> debts,
  required bool isAdventure,
}) =>
    showModalBottomSheet<SpoilsChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _BattleTurn(weapon: weapon, bosses: bosses, debts: debts, isAdventure: isAdventure),
    );

class _BattleTurn extends StatefulWidget {
  const _BattleTurn({required this.weapon, required this.bosses, required this.debts, required this.isAdventure});

  final BattleWeapon weapon;
  final List<GoalBoss> bosses;
  final List<DebtMonster> debts;
  final bool isAdventure;

  @override
  State<_BattleTurn> createState() => _BattleTurnState();
}

class _BattleTurnState extends State<_BattleTurn> {
  late SpoilsChoice _choice = widget.weapon.defaultChoice;

  /// The leftover with its goals and debts where earlier weapons left them,
  /// so the preview matches what the ledger will do.
  late final SliceLeftover _leftover =
      leftoverAgainst(widget.weapon.leftover, bosses: widget.bosses, debts: widget.debts);

  /// The moves this leftover can make, each with its label: the debts and
  /// goals it can reach that are still standing (an earlier weapon may have
  /// cleared a shared debt or finished a goal), then savings and keeping it.
  List<(SpoilsChoice, String)> get _options {
    final leftover = _leftover;
    final savingsLabel = Glossary.vaultLabel(isAdventure: widget.isAdventure, savingsRules: leftover.savingsRules);
    return [
      for (final debt in widget.debts)
        if (debt.outstandingCents > 0 && leftover.overbudgetOptions.any((option) => option.sliceId == debt.sliceId))
          (SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: debt.sliceId), 'Pay off ${debt.name}'),
      for (final boss in widget.bosses)
        if (boss.remainingCents > 0 && leftover.questOptions.any((option) => option.questId == boss.questId))
          (SpoilsChoice(SpoilsMove.goal, questId: boss.questId), 'Toward ${boss.name}'),
      (const SpoilsChoice(SpoilsMove.bank), 'Bank it in your $savingsLabel'),
      (const SpoilsChoice(SpoilsMove.carry), 'Keep it in ${widget.weapon.name}'),
    ];
  }

  /// The listed option matching [_choice]. A bank or carry default may
  /// carry a stray quest id, so those match by move. A debt that is no
  /// longer offered falls back to another standing debt, and a goal or debt
  /// with nothing left to aim at falls back to banking it.
  SpoilsChoice _selected(List<(SpoilsChoice, String)> options) {
    for (final (choice, _) in options) {
      if (choice == _choice) return choice;
    }
    if (_choice.move == SpoilsMove.debt) {
      for (final (choice, _) in options) {
        if (choice.move == SpoilsMove.debt) return choice;
      }
    }
    final move = _choice.move == SpoilsMove.carry ? SpoilsMove.carry : SpoilsMove.bank;
    return options.firstWhere((option) => option.$1.move == move).$1;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final selected = _selected(options);
    final preview = previewSpoilsChoice(_leftover, selected);
    final taxLine = preview.taxCents > 0
        ? '${money(preview.taxCents)} goes to ${widget.isAdventure ? 'the war chest' : 'shared savings'} on the way.'
        : 'Nothing is taken on the way.';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${widget.weapon.name}: ${money(widget.weapon.valueCents)} left over',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          RadioGroup<SpoilsChoice>(
            groupValue: selected,
            onChanged: (value) {
              if (value != null) setState(() => _choice = value);
            },
            child: Column(children: [
              for (final (choice, label) in options) RadioListTile<SpoilsChoice>(value: choice, title: Text(label)),
            ]),
          ),
          const Divider(),
          Text('${money(preview.landsCents)} lands. $taxLine', key: const ValueKey('battle-preview')),
          if (preview.toPersonalCents > 0)
            Text('${money(preview.toPersonalCents)} left after the debt goes to your savings.'),
          if (preview.completesTarget) const Text('That finishes it!'),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(selected),
              child: Text(widget.isAdventure ? 'Strike' : 'Confirm'),
            ),
          ),
        ]),
      ),
    );
  }
}
