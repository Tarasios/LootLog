import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';
import 'package:lootlog/game/domain/town/town_scatter.dart';

const layout = TownLayout.standard;

bool insideTown(TownProp prop) =>
    prop.column >= 0 && prop.column < layout.columns && prop.row >= 0 && prop.row < layout.rows;

Set<TownCell> footprintCells(List<TownCell> origins) => {
      for (final origin in origins)
        for (var column = 0; column < TownLayout.footprint; column++)
          for (var row = 0; row < TownLayout.footprint; row++) TownCell(origin.column + column, origin.row + row),
    };

void main() {
  test('the same seed scatters the same props', () {
    final first = scatterTown(layout, seed: 42);
    final second = scatterTown(layout, seed: 42);
    expect(first.props, second.props);
    expect(first.borderWidth, 6);
  });

  test('a different seed scatters differently', () {
    expect(scatterTown(layout, seed: 1).props, isNot(scatterTown(layout, seed: 2).props));
  });

  test('every cell of the border ring holds exactly one prop', () {
    for (final borderWidth in [1, 6]) {
      final scatter = scatterTown(layout, seed: 7, borderWidth: borderWidth);
      final border = scatter.props.where((prop) => !insideTown(prop)).toList();
      final cells = {for (final prop in border) TownCell(prop.column, prop.row)};
      final ringArea = (layout.columns + 2 * borderWidth) * (layout.rows + 2 * borderWidth) -
          layout.columns * layout.rows;
      expect(border, hasLength(ringArea));
      expect(cells, hasLength(ringArea));
      for (final cell in cells) {
        expect(cell.column, inInclusiveRange(-borderWidth, layout.columns + borderWidth - 1));
        expect(cell.row, inInclusiveRange(-borderWidth, layout.rows + borderWidth - 1));
      }
    }
  });

  test('no border without a border width', () {
    expect(scatterTown(layout, seed: 7, borderWidth: 0).props.where((prop) => !insideTown(prop)), isEmpty);
  });

  test('in-town props stand only on free grass', () {
    final blocked = <TownCell>{
      ...footprintCells(layout.plotOrigins),
      ...footprintCells(layout.houseOrigins),
      layout.gate,
      ...layout.statueSpots,
      ...layout.treeCells,
    };
    for (final seed in [0, 1, 2, 3, 99]) {
      final inTown = scatterTown(layout, seed: seed).props.where(insideTown).toList();
      expect(inTown, isNotEmpty, reason: 'seed $seed');
      for (final prop in inTown) {
        final cell = TownCell(prop.column, prop.row);
        expect(layout.groundAt(cell), TownGround.grass, reason: '$cell (seed $seed)');
        expect(blocked.contains(cell), isFalse, reason: '$cell (seed $seed)');
      }
    }
  });

  test('in-town density is light, around six percent of free grass', () {
    var freeGrass = 0;
    final blocked = <TownCell>{
      ...footprintCells(layout.plotOrigins),
      ...footprintCells(layout.houseOrigins),
      layout.gate,
      ...layout.statueSpots,
      ...layout.treeCells,
    };
    for (var column = 0; column < layout.columns; column++) {
      for (var row = 0; row < layout.rows; row++) {
        final cell = TownCell(column, row);
        if (layout.groundAt(cell) == TownGround.grass && !blocked.contains(cell)) freeGrass++;
      }
    }
    var placed = 0;
    const seeds = 20;
    for (var seed = 0; seed < seeds; seed++) {
      placed += scatterTown(layout, seed: seed).props.where(insideTown).length;
    }
    final density = placed / (freeGrass * seeds);
    expect(density, inInclusiveRange(0.04, 0.08));
  });

  test('every prop key exists in the bundled tiny town pack', () {
    final regions = (jsonDecode(File('assets/game/packs/tiny_town/regions.json').readAsStringSync())
        as Map<String, dynamic>)['regions'] as Map<String, dynamic>;
    final keys = {for (final prop in scatterTown(layout, seed: 5).props) prop.assetKey};
    expect(keys, containsAll(['town.tree.default.idle', 'town.bush.default.idle']));
    for (final key in keys) {
      expect(regions.containsKey(key), isTrue, reason: key);
    }
  });
}
