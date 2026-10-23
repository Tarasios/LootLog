part of '../text_adventure_view.dart';

/// The dungeon entrance: this floor's monsters and party contracts.
extension _DungeonEntranceSection on TextAdventureView {
  Widget _dungeonEntrance(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = game.monsters.isEmpty &&
        game.contracts.isEmpty &&
        game.party.every((partyMember) => partyMember.monsters.isEmpty && partyMember.contracts.isEmpty);
    return TextPanel(
      title: 'The Dungeon Entrance',
      icon: Icons.grid_view_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (empty)
            Text('No monsters stir on this floor yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'Floor ${game.floorNumber} gapes ahead. Within, the '
                'monsters stir:',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            ),
          for (final monster in game.monsters) _monsterLine(context, monster),
          for (final contract in game.contracts) _contractLine(context, contract),
          for (final partyMember in game.party)
            if (partyMember.monsters.isNotEmpty || partyMember.contracts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('${partyMember.name}\'s charges',
                    style: monoStyle(context, color: scheme.secondary)),
              ),
              for (final monster in partyMember.monsters) _monsterLine(context, monster),
              for (final contract in partyMember.contracts) _contractLine(context, contract),
            ],
        ],
      ),
    );
  }

  Widget _monsterLine(BuildContext context, Monster monster) {
    final scheme = Theme.of(context).colorScheme;
    final tag = monster.enraged
        ? 'ENRAGED +${money(monster.excessCents)}'
        : (monster.defeated ? 'FELLED ✓' : (monster.mine ? 'yours' : monster.ownerName ?? ''));
    final tint =
        monster.enraged ? scheme.error : (monster.defeated ? scheme.tertiary : null);
    return _hpLine(
      context,
      name: monster.name,
      bar: textBar(monster.hp.fraction),
      value: '${money(monster.damageCents)} / ${money(monster.maxHpCents)}',
      tag: tag,
      tint: tint,
    );
  }

  Widget _contractLine(BuildContext context, PartyContract contract) {
    final scheme = Theme.of(context).colorScheme;
    return _hpLine(
      context,
      name: '${contract.name} (party)',
      bar: textBar(contract.hp.fraction),
      value: '${money(contract.damageCents)} / ${money(contract.maxHpCents)}',
      tag: contract.enraged ? 'ENRAGED +${money(contract.excessCents)}' : 'shared',
      tint: contract.enraged ? scheme.error : scheme.secondary,
    );
  }
}
