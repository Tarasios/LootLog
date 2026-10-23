/// The town's bottom bar: Log a purchase (primary, one tap from launch),
/// Shop, Inbox and Budget.
library;

import 'package:flutter/material.dart';

class TownBottomBar extends StatelessWidget {
  const TownBottomBar({
    super.key,
    required this.onLogPurchase,
    required this.onShop,
    required this.onInbox,
    required this.onBudget,
    this.inboxCount = 0,
  });

  final VoidCallback onLogPurchase;
  final VoidCallback onShop;
  final VoidCallback onInbox;
  final VoidCallback onBudget;

  /// Unopened chests plus unclaimed rewards, shown as a badge.
  final int inboxCount;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 8,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onLogPurchase,
                icon: const Icon(Icons.add),
                label: const Text('Log a purchase'),
              ),
            ),
            _BarButton(icon: Icons.storefront, label: 'Shop', onPressed: onShop),
            _BarButton(
              icon: Icons.inbox,
              label: 'Inbox',
              onPressed: onInbox,
              badge: inboxCount > 0 ? '$inboxCount' : null,
            ),
            _BarButton(icon: Icons.menu_book, label: 'Budget', onPressed: onBudget),
          ],
        ),
      ),
    ),
  );
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String? badge;

  @override
  Widget build(BuildContext context) => Expanded(
    child: TextButton(
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Badge(
            isLabelVisible: badge != null,
            label: Text(badge ?? ''),
            child: Icon(icon),
          ),
          Text(label),
        ],
      ),
    ),
  );
}
