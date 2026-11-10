/// [SheetImageBuilder] hands its builder the decoded sheet, and never a stale
/// one: once the asset path changes, the old sheet is dropped until the new
/// one arrives.
library;

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/sheet_image.dart';

const String _townSheet = 'assets/game/packs/tiny_town/tilemap_packed.png';
const String _missingSheet = 'assets/game/packs/no_such_pack/tilemap_packed.png';

void main() {
  testWidgets('changing the path drops the old image', (tester) async {
    ui.Image? built;
    final loadErrors = <Object>[];
    Widget host(String path) => SheetImageBuilder(
          assetPath: path,
          onError: (error, _) => loadErrors.add(error),
          builder: (context, image) {
            built = image;
            return const SizedBox.shrink();
          },
        );

    await tester.pumpWidget(host(_townSheet));
    for (var attempt = 0; attempt < 50 && built == null; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(built, isNotNull, reason: 'the town sheet decodes');

    await tester.pumpWidget(host(_missingSheet));
    expect(built, isNull, reason: 'the town sheet is not shown for another path');

    for (var attempt = 0; attempt < 50 && loadErrors.isEmpty; attempt++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    expect(loadErrors, isNotEmpty, reason: 'the missing sheet reports through onError');
    expect(built, isNull);
  });
}
