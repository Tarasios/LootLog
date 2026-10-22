import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_catalog.dart';
import 'package:lootlog/game/assets/asset_registry.dart';
import 'package:lootlog/game/domain/game_values.dart';
import 'package:lootlog/game/dungeon_state.dart';
import 'package:lootlog/game/game_sprite.dart';
import 'package:lootlog/game/skin_prefs.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

/// Records every ref asked of it; resolves to a static image only for refs in
/// [hits] (by asset name or custom sha), otherwise null.
class _RecordingResolver implements SpriteResolver {
  _RecordingResolver({this.hits = const {}});

  final Set<String> hits;
  final List<SpriteRef> asked = [];

  @override
  ImageProvider? resolve(SpriteRef ref) {
    asked.add(ref);
    final id = ref.customSpriteSha256 ?? ref.assetName;
    return hits.contains(id) ? _StaticImageProvider(_checker) : null;
  }
}

final ui.Image _checker = () {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(const Rect.fromLTWH(0, 0, 32, 32),
      Paint()..color = const Color(0xFF6DAA2C));
  return recorder.endRecording().toImageSync(32, 32);
}();

/// Delivers an already-decoded image synchronously (no async decode in tests).
class _StaticImageProvider extends ImageProvider<_StaticImageProvider> {
  _StaticImageProvider(this.image);

  final ui.Image image;

  @override
  Future<_StaticImageProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_StaticImageProvider>(this);

  @override
  ImageStreamCompleter loadImage(
          _StaticImageProvider key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(
          SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone())));

  @override
  bool operator ==(Object other) =>
      other is _StaticImageProvider && identical(other.image, image);

  @override
  int get hashCode => image.hashCode;
}

Finder _textCard() => find.byType(TextSpriteCard);

void main() {
  group('spriteFrameCount', () {
    test('parses the _Nf suffix', () {
      expect(spriteFrameCount('monster_idle_4f.png'), 4);
      expect(spriteFrameCount('coin_spin_6f.png'), 6);
      expect(spriteFrameCount('gold_pouch_1f.png'), 1);
      expect(spriteFrameCount('big_12f.png'), 12);
    });

    test('missing or malformed suffix is a single frame', () {
      expect(spriteFrameCount('no_suffix.png'), 1);
      expect(spriteFrameCount('trophy.png'), 1);
      expect(spriteFrameCount('weird_0f.png'), 1);
      expect(spriteFrameCount('frames_2.png'), 1); // no trailing f
    });

    test('reads keyed filenames too', () {
      expect(spriteFrameCount('building.lumberyard.t2.idle_4f.png'), 4);
      expect(spriteFrameCount('chest.gold.open.idle.png'), 1);
    });
  });

  group('spriteFrameSrc', () {
    test('slices a horizontal strip into uniform frames', () {
      const size = Size(64, 16); // 4 frames of 16
      expect(spriteFrameSrc(size, 4, 0), const Rect.fromLTWH(0, 0, 16, 16));
      expect(spriteFrameSrc(size, 4, 2), const Rect.fromLTWH(32, 0, 16, 16));
    });

    test('wraps the frame index and guards a zero count', () {
      const size = Size(48, 16);
      expect(spriteFrameSrc(size, 3, 5), const Rect.fromLTWH(48 / 3 * 2, 0, 16, 16));
      expect(spriteFrameSrc(size, 0, 0), const Rect.fromLTWH(0, 0, 48, 16));
    });
  });

  group('GameSprite placeholder', () {
    testWidgets('renders a labelled placeholder when art is unavailable',
        (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.asset('missing_4f.png', label: 'War Chest'),
        // Default PlaceholderSpriteResolver -> never resolves.
      )));
      await tester.pump();
      // Initials of the label are shown; no exception is thrown.
      expect(find.text('WC'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sizes the box to base * integer scale', (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.asset('missing_1f.png', label: 'Gold'),
        scale: 4,
      )));
      await tester.pump();
      final box = tester.getSize(find.byType(GameSprite));
      expect(box.width, kSpriteBaseSize * 4);
      expect(box.height, kSpriteBaseSize * 4);
    });

    testWidgets('an unresolved custom blob also shows a placeholder',
        (tester) async {
      await tester.pumpWidget(_host(const GameSprite(
        sprite: SpriteRef.custom('deadbeef', label: 'Mochi'),
        resolver: AssetSpriteResolver(), // no bytes for the sha -> null
      )));
      await tester.pump();
      expect(find.text('M'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('GameSprite.widgetFrameCount treats custom sprites as single-frame', () {
    expect(
      GameSprite.widgetFrameCount(
          const SpriteRef.custom('abc', label: 'x')),
      1,
    );
    expect(
      GameSprite.widgetFrameCount(
          const SpriteRef.asset('a_4f.png', label: 'x')),
      4,
    );
    expect(
      GameSprite.widgetFrameCount(
          const SpriteRef.key(GameAssetKeys.dungeonCoin)),
      6,
    );
  });

  group('SpriteRef.key', () {
    test('defaults its label to the key title', () {
      expect(SpriteRef.key(GameAssetKeys.chest(ChestType.gold)).label,
          'Gold Chest');
      expect(
          const SpriteRef.key(GameAssetKeys.heroPortrait, label: 'Ayla').label,
          'Ayla');
    });

    test('equality includes the key', () {
      expect(const SpriteRef.key(GameAssetKeys.gem),
          const SpriteRef.key(GameAssetKeys.gem));
      expect(const SpriteRef.key(GameAssetKeys.gem),
          isNot(const SpriteRef.key(GameAssetKeys.freezeToken)));
    });
  });

  group('GameSprite.fromKey (pixel tier)', () {
    testWidgets('a key with no art renders its text card, not an error',
        (tester) async {
      final resolver = _RecordingResolver();
      await tester.pumpWidget(_host(GameSprite.fromKey(
        GameAssetKeys.building(BuildingType.lumberyard, 2),
        resolver: resolver,
      )));
      await tester.pump();
      expect(_textCard(), findsOneWidget);
      expect(find.text('Lumberyard'), findsOneWidget);
      expect(find.text('T2'), findsOneWidget);
      expect(resolver.asked, isEmpty); // nothing registered -> no lookup
      expect(tester.takeException(), isNull);
    });

    testWidgets('a registered key asks the resolver for its bundled file',
        (tester) async {
      final resolver = _RecordingResolver(hits: {'monster_idle_4f.png'});
      await tester.pumpWidget(_host(GameSprite.fromKey(
        GameAssetKeys.dungeonMonster,
        resolver: resolver,
      )));
      await tester.pump();
      expect(resolver.asked.single.assetName, 'monster_idle_4f.png');
      expect(_textCard(), findsNothing);
      expect(
          find.descendant(
              of: find.byType(GameSprite), matching: find.byType(CustomPaint)),
          findsOneWidget);
    });

    testWidgets('state falls back to idle along the chain', (tester) async {
      final resolver = _RecordingResolver();
      await tester.pumpWidget(_host(GameSprite.fromKey(
        GameAssetKeys.dungeonPet.withState('sleeping'),
        resolver: resolver,
      )));
      await tester.pump();
      expect(resolver.asked.single.assetName, 'pet_idle_4f.png');
      // The resolver had no image for it -> the text card, never grey.
      expect(_textCard(), findsOneWidget);
    });

    testWidgets('a custom blob wins over registered art', (tester) async {
      final resolver = _RecordingResolver(hits: {'abc'});
      await tester.pumpWidget(_host(GameSprite(
        sprite: const SpriteRef.key(GameAssetKeys.dungeonPet,
            label: 'Mochi', customSpriteSha256: 'abc'),
        resolver: resolver,
      )));
      await tester.pump();
      expect(resolver.asked.map((r) => r.customSpriteSha256 ?? r.assetName),
          ['abc']);
      expect(_textCard(), findsNothing);
    });

    testWidgets('an unavailable custom blob falls through to the key art',
        (tester) async {
      final resolver = _RecordingResolver(hits: {'pet_idle_4f.png'});
      await tester.pumpWidget(_host(GameSprite(
        sprite: const SpriteRef.key(GameAssetKeys.dungeonPet,
            label: 'Mochi', customSpriteSha256: 'missing'),
        resolver: resolver,
      )));
      await tester.pump();
      expect(resolver.asked.map((r) => r.customSpriteSha256 ?? r.assetName),
          ['missing', 'pet_idle_4f.png']);
      expect(_textCard(), findsNothing);
    });

    testWidgets('the scope registry supplies discovered art', (tester) async {
      final resolver = _RecordingResolver();
      await tester.pumpWidget(_host(GameSpriteScope(
        tier: AdventureTier.pixel,
        registry: const AssetRegistry({
          'chest.gold.closed.idle': 'chest.gold.closed.idle_1f.png',
        }),
        child: GameSprite.fromKey(GameAssetKeys.chest(ChestType.gold),
            resolver: resolver),
      )));
      await tester.pump();
      expect(resolver.asked.single.assetName, 'chest.gold.closed.idle_1f.png');
    });
  });

  group('GameSprite in the text tier', () {
    testWidgets('renders the text card even when art exists', (tester) async {
      final resolver = _RecordingResolver(hits: {'monster_idle_4f.png'});
      await tester.pumpWidget(_host(GameSprite.fromKey(
        GameAssetKeys.dungeonMonster,
        resolver: resolver,
        tier: AdventureTier.text,
      )));
      await tester.pump();
      expect(resolver.asked, isEmpty);
      expect(_textCard(), findsOneWidget);
      expect(find.text('Monster'), findsOneWidget);
    });

    testWidgets('reads the tier from an enclosing GameSpriteScope',
        (tester) async {
      final resolver = _RecordingResolver(hits: {'war_chest_1f.png'});
      await tester.pumpWidget(_host(GameSpriteScope(
        tier: AdventureTier.text,
        child: GameSprite(
          sprite: const SpriteRef.asset('war_chest_1f.png', label: 'War Chest'),
          resolver: resolver,
        ),
      )));
      await tester.pump();
      expect(resolver.asked, isEmpty);
      // A legacy filename ref has no key: the generic emblem under its label.
      expect(_textCard(), findsOneWidget);
      expect(find.text('War Chest'), findsOneWidget);
    });

    testWidgets('switching the scope tier re-renders as art', (tester) async {
      final resolver = _RecordingResolver(hits: {'coin_spin_6f.png'});
      Widget build(AdventureTier tier) => _host(GameSpriteScope(
            tier: tier,
            child: GameSprite.fromKey(GameAssetKeys.dungeonCoin,
                resolver: resolver),
          ));
      await tester.pumpWidget(build(AdventureTier.text));
      await tester.pump();
      expect(_textCard(), findsOneWidget);
      await tester.pumpWidget(build(AdventureTier.pixel));
      await tester.pump();
      expect(_textCard(), findsNothing);
      expect(resolver.asked.single.assetName, 'coin_spin_6f.png');
    });

    testWidgets('every catalogued key lays out cleanly at every size',
        (tester) async {
      for (final baseSize in const [kSpriteBaseSize, kPortraitBaseSize]) {
        for (final scale in const [1, 2, 4]) {
          await tester.pumpWidget(_host(Wrap(children: [
            for (final k in GameAssetKeys.all)
              GameSprite.fromKey(k,
                  scale: scale, baseSize: baseSize, tier: AdventureTier.text),
          ])));
          expect(tester.takeException(), isNull,
              reason: 'base $baseSize scale $scale');
        }
      }
    });

    testWidgets('small sprites show only the emblem', (tester) async {
      await tester.pumpWidget(_host(GameSprite.fromKey(
        GameAssetKeys.material(MaterialKind.ore),
        scale: 1,
        tier: AdventureTier.text,
      )));
      await tester.pump();
      expect(_textCard(), findsOneWidget);
      expect(find.text('Ore'), findsNothing);
      final box = tester.getSize(find.byType(GameSprite));
      expect(box, const Size.square(kSpriteBaseSize));
      expect(tester.takeException(), isNull);
    });
  });
}
