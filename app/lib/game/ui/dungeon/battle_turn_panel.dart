/// One turn of the month-end battle, on the screen beside the floor: the
/// current leftover as a wooden weapon card, the targets it can reach as
/// buttons, and Strike. Every number on the card is the shared move module's
/// preview (the reducer's own math) for the picked target, shown before the
/// strike is confirmed; this panel only hands back the chosen [SpoilsChoice].
library;

import 'package:flutter/material.dart';

import '../../../features/spoils/spoils_model.dart';
import '../../../features/spoils/spoils_move.dart';
import '../../../ui/format.dart';
import '../../../ui/glossary.dart';
import '../../assets/asset_key.dart';
import '../../assets/pack_sprite.dart';
import '../../battle/month_end_battle.dart';
import '../kit/kit.dart';

/// The weapon icon on the card (a pack sword; an artist PNG overrides it).
const AssetKey _weaponKey = AssetKey('item', 'weapon');

/// The turn for [weapon]: give each weapon its own key so a new turn starts
/// from that weapon's default target.
class BattleTurnPanel extends StatefulWidget {
  const BattleTurnPanel({
    super.key,
    required this.weapon,
    required this.bosses,
    required this.debts,
    required this.isAdventure,
    required this.onStrike,
    this.flavourLine,
    this.compact = false,
  });

  final BattleWeapon weapon;

  /// The goals and debts where earlier weapons in this battle left them.
  final List<GoalBoss> bosses;
  final List<DebtMonster> debts;
  final bool isAdventure;

  /// Called once per Strike with the picked target.
  final void Function(SpoilsChoice choice) onStrike;

  /// A line of game voice on the card ("Food gleams with $30…").
  final String? flavourLine;

  /// Narrow screens: targets wrap side by side instead of stacking.
  final bool compact;

  @override
  State<BattleTurnPanel> createState() => _BattleTurnPanelState();
}

class _BattleTurnPanelState extends State<BattleTurnPanel> {
  late SpoilsChoice _choice = widget.weapon.defaultChoice;

  /// The leftover with its goals and debts where earlier weapons left them,
  /// so the preview matches what the ledger will do.
  SliceLeftover get _leftover => leftoverAgainst(widget.weapon.leftover, bosses: widget.bosses, debts: widget.debts);

  /// The moves this leftover can make, each with its label: the debts and
  /// goals it can reach that are still standing (an earlier weapon may have
  /// cleared a shared debt or finished a goal), then savings and keeping it.
  List<(SpoilsChoice, String)> _optionsFor(SliceLeftover leftover) {
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
    final leftover = _leftover;
    final options = _optionsFor(leftover);
    final selected = _selected(options);
    final targets = [
      for (final (choice, label) in options)
        BattleTargetButton(
          choice: choice,
          label: label,
          selected: choice == selected,
          expand: !widget.compact,
          onPressed: () => setState(() => _choice = choice),
        ),
    ];
    final compact = widget.compact;
    final sectionGap = compact ? AdventureTokens.gap : AdventureTokens.gapLarge;
    // The card on top and Strike at the foot stay put; the targets between
    // them scroll when the screen is short.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeaponCard(
          weapon: widget.weapon,
          flavourLine: compact ? null : widget.flavourLine,
          preview: previewSpoilsChoice(leftover, selected),
          isAdventure: widget.isAdventure,
        ),
        SizedBox(height: sectionGap),
        if (!compact) ...[
          Text('Aim at', style: AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment)),
          const SizedBox(height: AdventureTokens.gap),
        ],
        Flexible(
          child: SingleChildScrollView(
            child: compact
                ? Wrap(spacing: AdventureTokens.gap, runSpacing: AdventureTokens.gap, children: targets)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, target) in targets.indexed) ...[
                        if (index > 0) const SizedBox(height: AdventureTokens.gap),
                        target,
                      ],
                    ],
                  ),
          ),
        ),
        SizedBox(height: sectionGap),
        WoodButton(
          label: widget.isAdventure ? 'Strike' : 'Confirm',
          expand: true,
          onPressed: () => widget.onStrike(selected),
        ),
      ],
    );
  }
}

/// One target the weapon can be aimed at: wood when picked, parchment
/// otherwise, announced as a selectable choice in a group.
class BattleTargetButton extends StatelessWidget {
  const BattleTargetButton({
    super.key,
    required this.choice,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.expand = false,
  });

  final SpoilsChoice choice;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: WoodButton(
          label: label,
          tone: selected ? WoodButtonTone.primary : WoodButtonTone.secondary,
          expand: expand,
          onPressed: onPressed,
        ),
      );
}

/// The leftover as a weapon: its category, its value, and what the picked
/// target would do with it — what lands and what the tithe takes on the way.
class _WeaponCard extends StatelessWidget {
  const _WeaponCard({
    required this.weapon,
    required this.flavourLine,
    required this.preview,
    required this.isAdventure,
  });

  final BattleWeapon weapon;
  final String? flavourLine;
  final SpoilsMovePreview preview;
  final bool isAdventure;

  @override
  Widget build(BuildContext context) {
    final taxLine = preview.taxCents > 0
        ? '${money(preview.taxCents)} goes to ${isAdventure ? 'the war chest' : 'shared savings'} on the way.'
        : 'Nothing is taken on the way.';
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdventureTokens.ink);
    return ParchmentCard(
      key: const ValueKey('next-weapon'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const PackSprite(assetKey: _weaponKey, label: 'Weapon'),
            const SizedBox(width: AdventureTokens.gap),
            Expanded(
              child: Text(weapon.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AdventureTokens.label(context)),
            ),
            const SizedBox(width: AdventureTokens.gap),
            Text(money(weapon.valueCents), style: AdventureTokens.amount(context)),
          ]),
          if (flavourLine case final String line) ...[
            const SizedBox(height: AdventureTokens.gap),
            Text(line,
                style: bodyStyle?.copyWith(color: AdventureTokens.inkMuted, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: AdventureTokens.gap),
          InsetWell(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${money(preview.landsCents)} lands. $taxLine',
                    key: const ValueKey('battle-preview'), style: bodyStyle?.copyWith(fontWeight: FontWeight.bold)),
                if (preview.toPersonalCents > 0)
                  Text('${money(preview.toPersonalCents)} left after the debt goes to your savings.',
                      style: bodyStyle),
                if (preview.completesTarget) Text('That finishes it!', style: bodyStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
