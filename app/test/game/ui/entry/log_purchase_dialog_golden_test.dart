/// The log-purchase dialog under the Adventure theme with the bundled UI pack
/// and pixel fonts: a desktop golden (keypad beside the destinations), and a
/// phone layout check (stacked, scrolling, no overflow).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/entry/charge_choice.dart';
import 'package:lootlog/game/assets/art_source.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/assets/game_asset_scope.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:lootlog/game/ui/entry/log_purchase_view.dart';
import 'package:lootlog/game/ui/kit/kit.dart';

/// A household's destinations, swatched by their main categories.
const List<ChargeGroup> _groups = [
  ChargeGroup(
    kind: ChargeGroupKind.personalSlice,
    label: 'My budgets',
    choices: [
      ChargeChoice(
        target: SliceCharge('dining'),
        label: 'Dining out',
        subtitle: '\$64.00 left',
        kind: ChargeGroupKind.personalSlice,
        supportsShared: true,
        colorArgb: 0xFFF28E2B,
      ),
      ChargeChoice(
        target: SliceCharge('games'),
        label: 'Games',
        subtitle: '\$0.00 left',
        kind: ChargeGroupKind.personalSlice,
        supportsShared: true,
        colorArgb: 0xFF59A14F,
      ),
      ChargeChoice(
        target: SliceCharge('transit'),
        label: 'Transit',
        subtitle: '\$45.50 left',
        kind: ChargeGroupKind.personalSlice,
        supportsShared: true,
        colorArgb: 0xFFE15759,
      ),
    ],
  ),
  ChargeGroup(
    kind: ChargeGroupKind.groupSlice,
    label: 'Shared budgets',
    choices: [
      ChargeChoice(
        target: SliceCharge('groceries'),
        label: 'Groceries',
        subtitle: '\$210.00 left',
        kind: ChargeGroupKind.groupSlice,
        supportsShared: false,
        colorArgb: 0xFFF28E2B,
      ),
      ChargeChoice(
        target: SliceCharge('pet-food'),
        label: 'Pip’s food',
        subtitle: '\$38.00 left',
        kind: ChargeGroupKind.groupSlice,
        supportsShared: false,
        colorArgb: 0xFFEDC948,
      ),
    ],
  ),
  ChargeGroup(
    kind: ChargeGroupKind.vault,
    label: 'Gold pouch',
    choices: [
      ChargeChoice(
        target: VaultCharge(),
        label: 'Gold pouch',
        subtitle: '\$88.50 available',
        kind: ChargeGroupKind.vault,
        supportsShared: true,
      ),
    ],
  ),
  ChargeGroup(
    kind: ChargeGroupKind.emergency,
    label: 'Emergency funds',
    choices: [
      ChargeChoice(
        target: EmergencyCharge('vet'),
        label: 'Vet bills',
        subtitle: '\$400.00 reserve',
        kind: ChargeGroupKind.emergency,
        supportsShared: false,
      ),
    ],
  ),
];

Future<void> _loadPixelFonts() async {
  for (final (family, asset) in [
    (AdventureTokens.pixelFont, 'assets/fonts/KenneyPixel.ttf'),
    (AdventureTokens.pixelMonoFont, 'assets/fonts/KenneyMiniSquare.ttf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

/// Decodes the kit frames' sheets so they paint on the next test frames.
Future<void> _decodeKitArt(WidgetTester tester, AssetRegistry registry) async {
  const frameKeys = [KitKeys.parchment, KitKeys.wood, KitKeys.inset, KitKeys.ribbon];
  final paths = {
    for (final key in frameKeys)
      switch (registry.artFor(key)) {
        ArtRegion(:final region) => '${AssetRegistry.assetDir}${region.sheetPath}',
        ArtFile(:final fileName) => '${AssetRegistry.assetDir}$fileName',
        null => null,
      },
  }.nonNulls;
  await tester.runAsync(() async {
    final element = tester.element(find.byType(Scaffold));
    for (final path in paths) {
      await precacheImage(AssetImage(path), element).timeout(const Duration(seconds: 30));
    }
  });
  for (var frame = 0; frame < 3; frame++) {
    await tester.pump();
  }
}

Future<void> _pumpDialog(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.runAsync(_loadPixelFonts);
  final registry = (await tester.runAsync(loadGameAssetRegistry))!;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AdventureTheme.build(),
      home: Scaffold(
        backgroundColor: AdventureTokens.grass,
        body: GameSpriteScope(
          tier: AdventureTier.pixel,
          registry: registry,
          child: LogPurchaseView(
            groups: _groups,
            initialCents: 1250,
            now: DateTime.utc(2026, 11, 9, 18),
            onCommit: (_) async {},
            onMoreDetails: (_) {},
            onClose: () {},
          ),
        ),
      ),
    ),
  );
  await _decodeKitArt(tester, registry);
}

void main() {
  testWidgets('log purchase dialog (desktop)', (tester) async {
    await _pumpDialog(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/log_purchase_dialog.png'),
    );
  });

  testWidgets('on a phone the keypad stacks over the destinations without '
      'overflow', (tester) async {
    await _pumpDialog(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    final keypadBottom = tester.getBottomLeft(find.text('0')).dy;
    final firstChipTop = tester.getTopLeft(find.text('Dining out')).dy;
    expect(firstChipTop, greaterThan(keypadBottom));
  });
}
