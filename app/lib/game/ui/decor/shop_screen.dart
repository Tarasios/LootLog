/// Today's shop: six items on a wood counter, a new set every day. Buying
/// spends gems earned by budgeting; nothing here touches money.
///
/// Full screen, no app bar: a wood header with the Shop ribbon, the back
/// button and the gem purse; the counter below holds the six slots (three
/// across on a wide screen, two on a phone) and the restock note.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/time.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../hall_common.dart';
import '../hall_ledger_view.dart';
import '../kit/kit.dart';
import 'shop_slot_card.dart';

/// From this counter width the slots sit three across (else two).
const double _kThreeAcrossWidth = 600;

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
    final narrow = MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;
    return HallScope(
      child: Scaffold(
        backgroundColor: AdventureTokens.parchmentDark,
        body: Column(
          children: [
            GameScreenHeader(
              title: 'Shop',
              trailing: [
                Semantics(
                  label: 'You have $gems gems',
                  excludeSemantics: true,
                  child: HudChip(
                    icon: Icons.diamond,
                    color: AdventureTokens.gem,
                    value: '$gems',
                    // A phone keeps the header's room for the ribbon.
                    label: narrow ? null : 'gems',
                    valueKey: const ValueKey('shop-gems'),
                  ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                // A phone keeps its width for the slots.
                padding: EdgeInsets.all(narrow ? AdventureTokens.gap : AdventureTokens.gapLarge),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: AdventureTokens.counterMaxWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WoodPanel(
                          key: const ValueKey('shop-counter'),
                          padding: const EdgeInsets.all(14),
                          child: shop.isEmpty
                              ? const ParchmentCard(
                                  child: Text('The shopkeeper is restocking. Check back soon.'),
                                )
                              : _SlotGrid(
                                  children: [
                                    for (final item in shop)
                                      ShopSlotCard(
                                        key: ValueKey('shop-${item.id}'),
                                        item: item,
                                        gems: gems,
                                        onBuy: () => _buy(context, ref, item),
                                      ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: AdventureTokens.gapLarge),
                        _RestockNote(hoursLeft: hoursLeft),
                      ],
                    ),
                  ),
                ),
              ),
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

/// The slots in equal-width columns: three across on a wide counter, two on
/// a narrow one. Every slot is the same height, so the rows line up.
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= _kThreeAcrossWidth ? 3 : 2;
          const spacing = AdventureTokens.gapLarge - 4;
          final slotWidth =
              ((constraints.maxWidth - spacing * (columns - 1)) / columns).floorToDouble();
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final child in children) SizedBox(width: slotWidth, child: child),
            ],
          );
        },
      );
}

/// "New stock tomorrow" with the hours left and where gems come from.
class _RestockNote extends StatelessWidget {
  const _RestockNote({required this.hoursLeft});

  final int hoursLeft;

  @override
  Widget build(BuildContext context) => InsetWell(
        key: const ValueKey('shop-restock-note'),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: AdventureTokens.inkMuted),
            const SizedBox(width: AdventureTokens.gap),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New stock tomorrow', style: AdventureTokens.label(context)),
                  const SizedBox(height: 2),
                  Text(
                    'Fresh finds arrive in about $hoursLeft ${hoursLeft == 1 ? 'hour' : 'hours'}. '
                    'Gems come from logging, so every entry adds to your haul.',
                    style: const TextStyle(color: AdventureTokens.ink),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
