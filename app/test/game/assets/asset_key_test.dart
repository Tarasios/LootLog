import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';

void main() {
  group('AssetKey.parse', () {
    test('reads the four dot-separated segments', () {
      final key = AssetKey.parse('building.lumberyard.t2.idle');
      expect(key.category, 'building');
      expect(key.subject, 'lumberyard');
      expect(key.variant, 't2');
      expect(key.state, 'idle');
      expect(key.value, 'building.lumberyard.t2.idle');
      expect(key.toString(), 'building.lumberyard.t2.idle');
    });

    test('accepts the guild-hall examples', () {
      for (final s in const [
        'chest.gold.closed.idle',
        'material.ore.icon.idle',
        'hero.portrait.default.idle',
        'region.subscription_swamp.banner.idle',
        'boss.frost_wyrm.default.idle',
        'homestead.stage.stage_0.idle',
      ]) {
        expect(AssetKey.parse(s).value, s);
      }
    });

    test('rejects malformed keys', () {
      for (final s in const [
        '',
        'building',
        'building.lumberyard.t2',
        'building.lumberyard.t2.idle.extra',
        'Building.lumberyard.t2.idle', // uppercase
        'building.lumber yard.t2.idle', // space
        'building..t2.idle', // empty segment
        'building.lumberyard.2t.idle', // leading digit
        'building.lumber-yard.t2.idle', // hyphen
        'building._lumberyard.t2.idle', // leading underscore
        'building.lumberyard_.t2.idle', // trailing underscore
        'building.lumber__yard.t2.idle', // double underscore
      ]) {
        expect(() => AssetKey.parse(s), throwsFormatException, reason: s);
        expect(AssetKey.tryParse(s), isNull, reason: s);
      }
    });
  });

  group('construction', () {
    test('defaults variant to default and state to idle', () {
      const key = AssetKey('hero', 'portrait');
      expect(key.value, 'hero.portrait.default.idle');
      expect(key.isValid, isTrue);
    });

    test('checked rejects invalid segments, the const form reports isValid',
        () {
      expect(() => AssetKey.checked('Hero', 'portrait'), throwsFormatException);
      expect(const AssetKey('Hero', 'portrait').isValid, isFalse);
      expect(AssetKey.checked('hero', 'portrait').isValid, isTrue);
    });

    test('value equality and hashing', () {
      expect(AssetKey.parse('chest.gold.open.idle'),
          const AssetKey('chest', 'gold', 'open'));
      expect(AssetKey.parse('chest.gold.open.idle').hashCode,
          const AssetKey('chest', 'gold', 'open').hashCode);
      expect(const AssetKey('chest', 'gold', 'open'),
          isNot(const AssetKey('chest', 'gold', 'closed')));
    });

    test('withState / withVariant swap one segment', () {
      const key = AssetKey('building', 'forge', 't3', 'idle');
      expect(key.withState('constructing').value,
          'building.forge.t3.constructing');
      expect(key.withVariant('default').value, 'building.forge.default.idle');
    });
  });

  group('fallbackChain', () {
    test('state falls back to idle, then variant to default', () {
      expect(
        AssetKey.parse('building.forge.t3.constructing')
            .fallbackChain
            .map((k) => k.value),
        [
          'building.forge.t3.constructing',
          'building.forge.t3.idle',
          'building.forge.default.constructing',
          'building.forge.default.idle',
        ],
      );
    });

    test('has no duplicates when segments are already the defaults', () {
      expect(
        AssetKey.parse('hero.portrait.default.idle')
            .fallbackChain
            .map((k) => k.value),
        ['hero.portrait.default.idle'],
      );
      expect(
        AssetKey.parse('chest.gold.open.idle').fallbackChain.map((k) => k.value),
        ['chest.gold.open.idle', 'chest.gold.default.idle'],
      );
    });
  });

  group('segment helpers', () {
    test('snakeSegment normalises enum names and free text', () {
      expect(AssetKey.snakeSegment('centralHall'), 'central_hall');
      expect(AssetKey.snakeSegment('subscriptionSwamp'), 'subscription_swamp');
      expect(AssetKey.snakeSegment('Bazaar of Whims'), 'bazaar_of_whims');
      expect(AssetKey.snakeSegment("Scribe's Desk"), 'scribes_desk');
      expect(AssetKey.snakeSegment('frost-wyrm 2'), 'frost_wyrm_2');
      expect(AssetKey.snakeSegment('  '), 'unknown');
      expect(AssetKey.snakeSegment('42'), 'x42');
    });

    test('displayName humanises the subject', () {
      expect(AssetKey.parse('building.lumberyard.t2.idle').displayName,
          'Lumberyard');
      expect(AssetKey.parse('region.subscription_swamp.banner.idle').displayName,
          'Subscription Swamp');
      expect(AssetKey.parse('region.bazaar_of_whims.banner.idle').displayName,
          'Bazaar of Whims');
      expect(AssetKey.parse('building.scribes_desk.t1.idle').displayName,
          "Scribe's Desk");
      expect(AssetKey.parse('building.hunters_lodge.t1.idle').displayName,
          "Hunter's Lodge");
    });
  });
}
