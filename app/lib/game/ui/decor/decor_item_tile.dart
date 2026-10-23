/// One decoration in a list: its sprite (or text card), name and a trailing
/// action.
library;

import 'package:flutter/material.dart';

import '../../assets/pack_sprite.dart';
import '../../domain/decor/catalog.dart';

class DecorItemTile extends StatelessWidget {
  const DecorItemTile({
    super.key,
    required this.item,
    this.trailing,
    this.subtitle,
  });

  final DecorItem item;
  final Widget? trailing;
  final String? subtitle;

  static const _rarityLabels = {
    DecorRarity.common: 'Common',
    DecorRarity.uncommon: 'Uncommon',
    DecorRarity.rare: 'Rare',
  };

  @override
  Widget build(BuildContext context) => ListTile(
    // The name sits beside the sprite, so the sprite's text card needs no
    // second copy of it.
    leading: SizedBox(
      width: 48,
      height: 48,
      child: Center(child: PackSprite(assetKey: item.assetKey, scale: 3)),
    ),
    title: Text(item.name, key: ValueKey('decor-name-${item.id}')),
    subtitle: Text(subtitle ?? _rarityLabels[item.rarity]!),
    trailing: trailing,
  );
}
