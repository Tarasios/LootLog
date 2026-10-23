/// One turn of the month-end battle: where a category's leftover goes. Every
/// number shown is the shared move module's preview (the reducer's own
/// math); this sheet only returns the chosen [SpoilsChoice].
library;

import 'package:flutter/material.dart';

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

  /// The moves this leftover can make, each with its label: the debts and
  /// goals it can reach, then savings and keeping it.
  List<(SpoilsChoice, String)> get _options {
    final leftover = widget.weapon.leftover;
    final savingsLabel = Glossary.vaultLabel(isAdventure: widget.isAdventure, savingsRules: leftover.savingsRules);
    return [
      for (final debt in widget.debts)
        if (leftover.overbudgetOptions.any((option) => option.sliceId == debt.sliceId))
          (SpoilsChoice(SpoilsMove.debt, overbudgetSliceId: debt.sliceId), 'Pay off ${debt.name}'),
      for (final boss in widget.bosses)
        if (leftover.questOptions.any((option) => option.questId == boss.questId))
          (SpoilsChoice(SpoilsMove.goal, questId: boss.questId), 'Toward ${boss.name}'),
      (const SpoilsChoice(SpoilsMove.bank), 'Bank it in your $savingsLabel'),
      (const SpoilsChoice(SpoilsMove.carry), 'Keep it in ${widget.weapon.name}'),
    ];
  }

  /// The listed option matching [_choice] (the default choice may carry a
  /// quest id alongside a bank or carry move).
  SpoilsChoice _selected(List<(SpoilsChoice, String)> options) {
    for (final (choice, _) in options) {
      if (choice == _choice) return choice;
    }
    for (final (choice, _) in options) {
      if (choice.move == _choice.move) return choice;
    }
    return options.first.$1;
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;
    final selected = _selected(options);
    final preview = previewSpoilsChoice(widget.weapon.leftover, selected);
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
