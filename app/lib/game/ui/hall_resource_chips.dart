/// The gem and material chips the framed hall screens show on their wood
/// header: this adult's gems and their town's materials, read from the
/// game state (display only).
library;

import 'package:flutter/material.dart';

import '../domain/game_values.dart';
import 'hall_names.dart';
import 'kit/kit.dart';

/// The icon a material's chip wears.
IconData materialIcon(MaterialKind kind) => switch (kind) {
      MaterialKind.lumber => Icons.forest,
      MaterialKind.stone => Icons.landscape,
      MaterialKind.ore => Icons.hexagon,
      MaterialKind.herbs => Icons.eco,
      MaterialKind.hide => Icons.layers,
      MaterialKind.crystal => Icons.change_history,
      MaterialKind.essence => Icons.auto_awesome,
      MaterialKind.trophy => Icons.emoji_events,
    };

/// This adult's gems as a chip; [compact] (a phone) drops the caption to keep
/// the header's room for the ribbon.
Widget gemsChip(int gems, {required bool compact}) => Semantics(
      label: 'You have ${HallNames.gems(gems)}',
      excludeSemantics: true,
      child: HudChip(
        key: const ValueKey('hall-gems-chip'),
        icon: Icons.diamond,
        color: AdventureTokens.gem,
        value: '$gems',
        label: compact ? null : 'gems',
        valueKey: const ValueKey('hall-gems'),
      ),
    );

/// One chip per kind in [kinds], showing how much of it the shared [pool]
/// holds (zero included, so the header does not jump as stores change).
List<Widget> materialChips(MaterialBundle pool, Iterable<MaterialKind> kinds) => [
      for (final kind in kinds)
        Semantics(
          label: '${pool[kind]} ${HallNames.material(kind)}',
          excludeSemantics: true,
          child: HudChip(
            icon: materialIcon(kind),
            value: '${pool[kind]}',
            valueKey: ValueKey('hall-material-${kind.name}'),
          ),
        ),
    ];

/// The town's stores as a single chip: everything in the stores, summed.
Widget storesChip(MaterialBundle pool, {required bool compact}) {
  final total = pool.amounts.values.fold<int>(0, (sum, amount) => sum + amount);
  return Semantics(
    label: '$total materials in the stores',
    excludeSemantics: true,
    child: HudChip(
      icon: Icons.inventory_2,
      value: '$total',
      label: compact ? null : 'in stores',
      valueKey: const ValueKey('hall-stores'),
    ),
  );
}
