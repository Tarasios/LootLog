import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/scenes/scene_pictures.dart';

Future<ui.Image> tinyImage() {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 2, 2), ui.Paint());
  return recorder.endRecording().toImage(2, 2);
}

void main() {
  testWidgets('a scene keeps its pictures after the shared copies are disposed', (tester) async {
    final shared = (await tester.runAsync(tinyImage))!;
    final scene = ScenePictures({'sha': shared});
    shared.dispose();
    expect(scene.images['sha']!.debugDisposed, isFalse);
    expect(scene.images['sha']!.isCloneOf(shared), isTrue);
    scene.dispose();
    expect(scene.images['sha']!.debugDisposed, isTrue);
  });
}
