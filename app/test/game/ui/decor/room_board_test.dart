/// The room board's sizing: the room at the largest whole zoom inside the
/// wood frame, overlapping the frame only to avoid the smallest zoom.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/ui/decor/room_board.dart';

void main() {
  // The room is 12 x 10 tiles of 16 pixels: 192 x 160.
  test('a desktop board keeps the room inside the frame', () {
    expect(RoomBoard.sceneSizeFor(const Size(1424, 796)), const Size(768, 640));
  });

  test('a phone board lets the room cover the frame rather than drop to 1x', () {
    expect(RoomBoard.sceneSizeFor(const Size(390, 590)), const Size(384, 320));
  });

  test('the scene never grows past a board too small for the room', () {
    expect(RoomBoard.sceneSizeFor(const Size(100, 100)), const Size(100, 100));
  });
}
