/// Today's shop: six items, a new set every day. Buying spends gems earned
/// by budgeting; nothing here touches money.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import 'decor_item_tile.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  static Future<void> open(BuildContext context) =>
      pushHallScreen(context, const ShopScreen());

  /// Whole hours until the shop restocks at the next household midnight.
  static int hoursUntilRestock(DateTime now) {
    final instant = now.toUtc();
    final local = instant.add(vancouverUtcOffset(instant));
    return 24 - local.hour;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shop = ref.watch(todaysShopProvider);
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId ?? '';
    final gems = game.person(meId).gems;
    final hoursLeft = hoursUntilRestock(hallNow(ref));
    return HallScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Shop')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.diamond, color: Color(0xFF6DC2CA)),
              title: Text('You have $gems gems'),
              subtitle: Text(
                'Fresh finds arrive in about $hoursLeft ${hoursLeft == 1 ? 'hour' : 'hours'}. '
                'Gems come from logging, so every entry adds to your haul.',
              ),
            ),
            const Divider(),
            for (final item in shop)
              DecorItemTile(
                key: ValueKey('shop-${item.id}'),
                item: item,
                trailing: gems >= item.priceGems!
                    ? FilledButton(
                        key: ValueKey('buy-${item.id}'),
                        onPressed: () => _buy(context, ref, item),
                        child: Text('${item.priceGems} gems'),
                      )
                    : Text('${item.priceGems! - gems} more gems'),
              ),
            if (shop.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('The shopkeeper is restocking. Check back soon.'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _buy(BuildContext context, WidgetRef ref, DecorItem item) async {
    final result = await runHallCommand(
      context,
      ref,
      (service) => service.buyItem(item.id),
    );
    if (result != null && result.accepted && context.mounted) {
      await showHallCelebration(
        context,
        sprite: item.assetKey,
        title: 'New for your home',
        lines: ['${item.name} is in your inventory.'],
      );
    }
  }
}
