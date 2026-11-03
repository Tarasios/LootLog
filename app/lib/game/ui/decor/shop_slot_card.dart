/// One slot on the shop counter: a parchment card with the item's rarity on a
/// hanging tag, its sprite in a sunken well, its name, its gem price, and a
/// wood Buy button — or, when the gems are short, a disabled button that
/// says how many more are needed.
library;

import 'package:flutter/material.dart';

import '../../assets/pack_sprite.dart';
import '../../domain/decor/catalog.dart';
import '../kit/kit.dart';

/// The sprite's magnification: a 16 px pack cell drawn 64 px.
const int _kSpriteScale = 4;

/// The well the sprite sits in is this tall, so every slot lines up.
const double _kSpriteWellHeight = 72;

class ShopSlotCard extends StatelessWidget {
  const ShopSlotCard({
    super.key,
    required this.item,
    required this.gems,
    required this.onBuy,
  });

  final DecorItem item;

  /// The viewer's gems, to tell whether the item is affordable.
  final int gems;
  final VoidCallback onBuy;

  static const _rarityLabels = {
    DecorRarity.common: 'Common',
    DecorRarity.uncommon: 'Uncommon',
    DecorRarity.rare: 'Rare',
  };

  @override
  Widget build(BuildContext context) {
    final price = item.priceGems!;
    final missingGems = price - gems;
    final rare = item.rarity == DecorRarity.rare;
    return ParchmentCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            // Shrinks only if a large text scale would push the tag past the
            // card's edge; at normal sizes it draws at its crisp native size.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: FloatingTag(
                _rarityLabels[item.rarity]!,
                icon: rare ? Icons.auto_awesome : null,
                urgent: rare,
              ),
            ),
          ),
          const SizedBox(height: 2),
          InsetWell(
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: _kSpriteWellHeight,
              // The name sits under the sprite, so the sprite's text card
              // needs no second copy of it.
              child: Center(child: PackSprite(assetKey: item.assetKey, scale: _kSpriteScale)),
            ),
          ),
          const SizedBox(height: AdventureTokens.gap),
          Text(
            item.name,
            key: ValueKey('decor-name-${item.id}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AdventureTokens.label(context),
          ),
          const SizedBox(height: 4),
          _GemPrice(price: price),
          const SizedBox(height: AdventureTokens.gap),
          if (missingGems <= 0)
            WoodButton(
              key: ValueKey('buy-${item.id}'),
              label: 'Buy',
              expand: true,
              onPressed: onBuy,
            )
          else
            WoodButton(
              key: ValueKey('short-${item.id}'),
              label: '$missingGems more gems',
              tone: WoodButtonTone.secondary,
              expand: true,
              onPressed: null,
            ),
        ],
      ),
    );
  }
}

/// "◆ 40": the gem icon and the price in the legible amount face.
class _GemPrice extends StatelessWidget {
  const _GemPrice({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$price gems',
        excludeSemantics: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.diamond, size: 18, color: AdventureTokens.gem),
            const SizedBox(width: 4),
            Text('$price', style: AdventureTokens.amount(context)),
          ],
        ),
      );
}
