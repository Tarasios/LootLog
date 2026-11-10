/// One decoration in a list (the wardrobe): its sprite (or text card) in a
/// small sunken well, its name and a caption in the kit's pixel faces, and a
/// trailing mark. With [DecorItemTile.onTap] the whole row is a kit button.
library;

import 'package:flutter/material.dart';

import '../../assets/pack_sprite.dart';
import '../../domain/decor/catalog.dart';
import '../kit/kit.dart';

/// The sprite's side, in logical pixels (a 16 px cell at 3×).
const double _kSpriteSide = 48;

class DecorItemTile extends StatelessWidget {
  const DecorItemTile({
    super.key,
    required this.item,
    this.trailing,
    this.subtitle,
    this.onTap,
  });

  final DecorItem item;
  final Widget? trailing;
  final String? subtitle;
  final VoidCallback? onTap;

  static const _rarityLabels = {
    DecorRarity.common: 'Common',
    DecorRarity.uncommon: 'Uncommon',
    DecorRarity.rare: 'Rare',
  };

  @override
  Widget build(BuildContext context) {
    final trailing = this.trailing;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          InsetWell(
            padding: const EdgeInsets.all(6),
            child: SizedBox.square(
              dimension: _kSpriteSide,
              // The name sits beside the sprite, so the sprite's text card
              // needs no second copy of it.
              child: Center(child: PackSprite(assetKey: item.assetKey, scale: 3)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  key: ValueKey('decor-name-${item.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AdventureTokens.label(context),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle ?? _rarityLabels[item.rarity]!,
                  style: AdventureTokens.label(context).copyWith(color: AdventureTokens.inkMuted),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: AdventureTokens.gap), trailing],
        ],
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return row;
    return KitPressable(onPressed: onTap, builder: (context, pressed) => row);
  }
}
