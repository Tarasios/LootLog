/// The party frames around the month-end dungeon's floor, as a pure view
/// model: one frame per adult, with a portrait key, a name and a meter.
///
/// No meter here measures money. This adult's meter counts the weapons swung
/// so far (turns, not cents); every other adult stands ready at full health,
/// because one partner's month never weakens another's frame (design rule 7).
/// A Standard adult is the supply caravan backing the party and is never
/// named. Pure Dart, zero Flutter imports.
library;

import '../../../ui/glossary.dart';
import '../../assets/asset_key.dart';

/// One adult as the party frames need them.
typedef PartyAdult = ({String memberId, String name, bool inAdventure});

/// What a frame shows: an adventuring hero, or the Standard adult's caravan.
enum PartyFrameRole { hero, caravan }

/// The default hero, for an adventurer with no outfit on.
const AssetKey _defaultHeroKey = AssetKey('hero', 'body');

/// The supply caravan's wagon (the town shows the same one).
const AssetKey _caravanKey = AssetKey('town', 'wagon');

class DungeonPartyFrame {
  const DungeonPartyFrame({
    required this.memberId,
    required this.name,
    required this.role,
    required this.isMe,
    required this.portraitKey,
    required this.meterFraction,
    required this.caption,
  });

  final String memberId;

  /// The adventurer's name, or "Supply caravan" for a Standard adult.
  final String name;
  final PartyFrameRole role;

  /// This device's adult: the one swinging the weapons.
  final bool isMe;
  final AssetKey portraitKey;

  /// The meter's fill, 0..1.
  final double meterFraction;

  /// A short line under the meter ("Weapons 1/3", "Ready").
  final String caption;
}

/// The frames for [adults] in the order given (this device's adult first in
/// the hall's view). [weaponsSwung] of [weaponCount] fill this adult's meter;
/// [outfitOf] gives a hero's outfit sprite, or null for the default hero.
List<DungeonPartyFrame> dungeonPartyFrames({
  required List<PartyAdult> adults,
  required String? meId,
  required int weaponsSwung,
  required int weaponCount,
  required AssetKey? Function(String memberId) outfitOf,
}) =>
    [
      for (final adult in adults)
        if (!adult.inAdventure)
          DungeonPartyFrame(
            memberId: adult.memberId,
            name: Glossary.capitalize(Glossary.supplyCaravan.adventure),
            role: PartyFrameRole.caravan,
            isMe: adult.memberId == meId,
            portraitKey: _caravanKey,
            meterFraction: 1,
            caption: 'Backing the party',
          )
        else if (adult.memberId == meId)
          DungeonPartyFrame(
            memberId: adult.memberId,
            name: adult.name,
            role: PartyFrameRole.hero,
            isMe: true,
            portraitKey: outfitOf(adult.memberId) ?? _defaultHeroKey,
            meterFraction: weaponsSwung >= weaponCount ? 1 : weaponsSwung / weaponCount,
            caption: weaponsSwung >= weaponCount ? 'All divided' : 'Weapons $weaponsSwung/$weaponCount',
          )
        else
          DungeonPartyFrame(
            memberId: adult.memberId,
            name: adult.name,
            role: PartyFrameRole.hero,
            isMe: false,
            portraitKey: outfitOf(adult.memberId) ?? _defaultHeroKey,
            meterFraction: 1,
            caption: 'Ready',
          ),
    ];
