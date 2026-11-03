import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/game/assets/asset_key.dart';
import 'package:lootlog/game/ui/dungeon/dungeon_party.dart';

void main() {
  const alex = (memberId: 'alex', name: 'Alex', inAdventure: true);
  const sam = (memberId: 'sam', name: 'Sam', inAdventure: true);
  const robin = (memberId: 'robin', name: 'Robin', inAdventure: false);
  const knight = AssetKey('hero', 'body', 'knight');

  List<DungeonPartyFrame> framesFor({
    List<PartyAdult> adults = const [alex, sam, robin],
    int swung = 1,
    int weapons = 3,
    AssetKey? Function(String memberId)? outfitOf,
  }) =>
      dungeonPartyFrames(
        adults: adults,
        meId: 'alex',
        weaponsSwung: swung,
        weaponCount: weapons,
        outfitOf: outfitOf ?? (_) => null,
      );

  test('one frame per adult, in the order given', () {
    expect(framesFor().map((frame) => frame.memberId), ['alex', 'sam', 'robin']);
  });

  test('my frame tracks the weapons swung, counted, never money', () {
    final me = framesFor().first;
    expect(me.isMe, isTrue);
    expect(me.name, 'Alex');
    expect(me.meterFraction, closeTo(1 / 3, 1e-9));
    expect(me.caption, 'Weapons 1/3');
  });

  test('my frame is full once every weapon is swung, or when there were none', () {
    expect(framesFor(swung: 3).first.meterFraction, 1);
    expect(framesFor(swung: 3).first.caption, 'All divided');
    expect(framesFor(swung: 0, weapons: 0).first.meterFraction, 1);
    expect(framesFor(swung: 0, weapons: 0).first.caption, 'All divided');
  });

  test('another adventurer stands ready at full health', () {
    final sam = framesFor()[1];
    expect(sam.isMe, isFalse);
    expect(sam.role, PartyFrameRole.hero);
    expect(sam.name, 'Sam');
    expect(sam.meterFraction, 1);
    expect(sam.caption, 'Ready');
  });

  test('a Standard adult is the unnamed supply caravan backing the party', () {
    final caravan = framesFor()[2];
    expect(caravan.role, PartyFrameRole.caravan);
    expect(caravan.name, 'Supply caravan');
    expect(caravan.name, isNot(contains('Robin')));
    expect(caravan.caption, isNot(contains('Robin')));
    expect(caravan.meterFraction, 1);
    expect(caravan.portraitKey, const AssetKey('town', 'wagon'));
  });

  test('heroes wear their outfit, or the default hero body', () {
    final frames = framesFor(outfitOf: (memberId) => memberId == 'sam' ? knight : null);
    expect(frames[0].portraitKey, const AssetKey('hero', 'body'));
    expect(frames[1].portraitKey, knight);
  });
}
