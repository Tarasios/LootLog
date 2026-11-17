/// The stage-3 district maps: the Guard Post, Residential Quarter, Park,
/// Market Row and Castle Hill. Each is a phone-sized 14 × 20 map with its
/// own look, a lane in from the west (the strip's previous district) and,
/// except the last, out to the east; one plot per plot the rules know,
/// clear of each other and of the landmarks, inside the band a phone's HUD
/// leaves free; and Castle Hill holds the Castle instead of plots.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/town/districts.dart';
import 'package:lootlog/game/domain/town/town_layout.dart';

const _quarters = [
  kGuardPostDistrictId,
  kResidentialDistrictId,
  kParkDistrictId,
  kMarketRowDistrictId,
];

Set<TownCell> _footprint(TownCell origin, {int columns = TownLayout.footprint, int rows = TownLayout.footprint}) => {
      for (var column = 0; column < columns; column++)
        for (var row = 0; row < rows; row++) TownCell(origin.column + column, origin.row + row),
    };

Set<TownCell> _cellsOf(TownLayout layout, TownGround ground) => {
      for (var column = 0; column < layout.columns; column++)
        for (var row = 0; row < layout.rows; row++)
          if (layout.groundAt(TownCell(column, row)) == ground) TownCell(column, row),
    };

bool _inside(TownLayout layout, TownCell cell) =>
    cell.column >= 0 && cell.row >= 0 && cell.column < layout.columns && cell.row < layout.rows;

void main() {
  for (final id in [..._quarters, kCastleHillDistrictId]) {
    group(id, () {
      final layout = TownLayout.forDistrict(id)!;

      test('is its own phone-sized map', () {
        expect(layout.districtId, id);
        expect(layout.columns, 14);
        expect(layout.rows, 20);
        expect(layout.hasGate, isFalse);
        expect(layout.houseOrigins, isEmpty);
        expect(layout.signpost, isNull);
      });

      test('a lane enters from the west edge', () {
        final west = [
          for (var row = 0; row < layout.rows; row++)
            if (layout.groundAt(TownCell(0, row)) != TownGround.grass) row,
        ];
        expect(west, isNotEmpty);
      });

      test('landmarks lie on the map, never in water, never on each other', () {
        final used = <TownCell>{};
        for (final landmark in layout.landmarks) {
          for (final cell in _footprint(landmark.origin, columns: landmark.columns, rows: landmark.rows)) {
            expect(_inside(layout, cell), isTrue, reason: '${landmark.label} at $cell is off the map');
            expect(layout.groundAt(cell), isNot(TownGround.water), reason: '${landmark.label} at $cell is in water');
            if (!landmark.underlay) expect(used.add(cell), isTrue, reason: '${landmark.label} at $cell is used twice');
          }
        }
      });
    });
  }

  for (final id in _quarters) {
    group('$id plots', () {
      final layout = TownLayout.forDistrict(id)!;

      test('one per plot the rules know', () {
        expect(layout.plotOrigins, hasLength(districtById(id)!.plotCount));
      });

      test('a lane runs on east to the next district', () {
        final east = [
          for (var row = 0; row < layout.rows; row++)
            if (layout.groundAt(TownCell(layout.columns - 1, row)) != TownGround.grass) row,
        ];
        expect(east, isNotEmpty);
      });

      test('plots and the row above them are clear of each other, landmarks, lanes and water', () {
        final landmarkCells = {
          for (final landmark in layout.landmarks)
            if (!landmark.underlay)
              ..._footprint(landmark.origin, columns: landmark.columns, rows: landmark.rows),
        };
        final used = <TownCell>{};
        for (final origin in layout.plotOrigins) {
          final overhang = TownCell(origin.column, origin.row - 1);
          for (final cell in {..._footprint(origin), ..._footprint(overhang, rows: 1)}) {
            expect(_inside(layout, cell), isTrue, reason: '$cell is off the map');
            expect(layout.groundAt(cell), TownGround.grass, reason: '$cell is not grass');
            expect(landmarkCells.contains(cell), isFalse, reason: 'a landmark stands on $cell');
            expect(used.add(cell), isTrue, reason: '$cell is used twice');
          }
        }
      });

      test('every plot is a step or two from a lane', () {
        final lanes = {..._cellsOf(layout, TownGround.path), ..._cellsOf(layout, TownGround.square)};
        for (final origin in layout.plotOrigins) {
          final near = {
            for (var column = origin.column - 2; column < origin.column + 4; column++)
              for (var row = origin.row - 2; row < origin.row + 4; row++) TownCell(column, row),
          };
          expect(near.any(lanes.contains), isTrue, reason: 'plot at $origin is off the lanes');
        }
      });

      test('plots sit in the band a phone HUD leaves free', () {
        for (final origin in layout.plotOrigins) {
          expect(origin.row - 1, greaterThanOrEqualTo(4), reason: 'plot at $origin is under the top HUD');
          expect(origin.row + 1, lessThanOrEqualTo(15), reason: 'plot at $origin is under the bottom HUD');
          expect(origin.column, greaterThanOrEqualTo(1), reason: 'plot at $origin hugs the west edge');
          expect(origin.column + 1, lessThanOrEqualTo(12), reason: 'plot at $origin hugs the east edge');
        }
      });

      test('has no castle', () => expect(layout.castleOrigin, isNull));
    });
  }

  test('each quarter has its own look', () {
    final guard = TownLayout.forDistrict(kGuardPostDistrictId)!;
    final market = TownLayout.forDistrict(kMarketRowDistrictId)!;
    final park = TownLayout.forDistrict(kParkDistrictId)!;
    final residential = TownLayout.forDistrict(kResidentialDistrictId)!;
    Set<String> keys(TownLayout layout) => {for (final landmark in layout.landmarks) landmark.assetKey};
    expect(keys(guard), containsAll(['guard.wall.default.idle', 'guard.tower.default.idle', 'guard.gate.default.idle']));
    expect(_cellsOf(market, TownGround.square), isNotEmpty, reason: 'a cobbled street');
    expect(keys(market).where((key) => key.startsWith('market.stall')), isNotEmpty);
    expect(_cellsOf(park, TownGround.water), isNotEmpty, reason: 'a pond');
    expect(keys(park), containsAll(['park.bench.default.idle', 'park.flowerbed.default.idle']));
    expect(keys(residential), contains('residential.garden.default.idle'));
    expect(keys(residential), contains('town.fence.default.idle'));
  });

  group('Castle Hill', () {
    final layout = TownLayout.forDistrict(kCastleHillDistrictId)!;

    test('has no plots: the Castle stands on its hill', () {
      expect(layout.plotOrigins, isEmpty);
      final origin = layout.castleOrigin!;
      expect(layout.castleColumns, greaterThanOrEqualTo(4));
      expect(_inside(layout, origin), isTrue);
      expect(_inside(layout, TownCell(origin.column + layout.castleColumns - 1, origin.row + layout.castleRows - 1)),
          isTrue);
      expect(layout.landmarks.map((landmark) => landmark.assetKey), contains('castle.hill.default.idle'));
    });

    test('the castle covers its cells and nothing else does', () {
      final origin = layout.castleOrigin!;
      expect(layout.castleCovers(origin), isTrue);
      expect(layout.castleCovers(TownCell(origin.column + 1, origin.row + 1)), isTrue);
      expect(layout.castleCovers(const TownCell(0, 0)), isFalse);
    });
  });

  test('the strip neighbours share the row the lane crosses between them', () {
    // Each district's east exit meets the next one's west entrance.
    final order = [kFarmlandDistrictId, ..._quarters, kCastleHillDistrictId];
    for (var index = 1; index < order.length - 1; index++) {
      final layout = TownLayout.forDistrict(order[index])!;
      expect(layout.groundAt(const TownCell(0, 9)), isNot(TownGround.grass), reason: '${order[index]} west');
      expect(layout.groundAt(TownCell(layout.columns - 1, 9)), isNot(TownGround.grass), reason: '${order[index]} east');
    }
  });
}
