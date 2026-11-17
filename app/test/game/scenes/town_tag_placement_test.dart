import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/domain/game_state.dart';
import 'package:lootlog/game/domain/town/town_tags.dart';
import 'package:lootlog/game/domain/town/town_view.dart';
import 'package:lootlog/game/scenes/camera_controls.dart';
import 'package:lootlog/game/scenes/town/town_tag_placement.dart';

const _adults = [
  TownAdult(memberId: 'alex', name: 'Alex', inAdventure: true),
  TownAdult(memberId: 'sam', name: 'Sam', inAdventure: true),
];

final TownView _view = TownView.from(
  GameState.initial(),
  'alex',
  _adults,
  DateTime.utc(2026, 10, 1),
);

void main() {
  test('a plot tag hangs over the middle of the plot top edge', () {
    final placed = placeTownTags(const [
      TownTag(anchor: PlotAnchor(0), text: 'Chest waiting'),
    ], _view);
    // Plot 0 starts at cell (9, 7) and is two cells wide.
    expect(placed.single.worldX, 10 * kTileSize);
    expect(placed.single.worldY, 7 * kTileSize);
  });

  test("a house tag hangs over its resident's house", () {
    final placed = placeTownTags(const [
      TownTag(anchor: HouseAnchor('sam'), text: 'Rent in 2d'),
    ], _view);
    // Sam has the second house slot, cell (17, 12).
    expect(placed.single.worldX, 18 * kTileSize);
    expect(placed.single.worldY, 12 * kTileSize);
  });

  test('the gate tag hangs over the gate cell', () {
    final placed = placeTownTags(const [
      TownTag(anchor: GateAnchor(), text: '2 to divide', urgent: true),
    ], _view);
    expect(placed.single.worldX, 27 * kTileSize + kTileSize / 2);
    expect(placed.single.worldY, 10 * kTileSize);
  });

  test('goal tags take opposite corners of the square first', () {
    final placed = placeTownTags(const [
      TownTag(anchor: StatueAnchor('jacket'), text: 'Jacket 50%'),
      TownTag(anchor: StatueAnchor('canoe'), text: 'Canoe 10%'),
    ], _view);
    expect(placed.map((tag) => (tag.worldX, tag.worldY)), [
      (12 * kTileSize + kTileSize / 2, 8 * kTileSize),
      (15 * kTileSize + kTileSize / 2, 11 * kTileSize),
    ]);
  });

  test('a tag whose house is not in the town is left out', () {
    final placed = placeTownTags(const [
      TownTag(anchor: HouseAnchor('nobody'), text: 'Rent in 2d'),
      TownTag(anchor: PlotAnchor(99), text: 'Ready to upgrade'),
    ], _view);
    expect(placed, isEmpty);
  });
}
