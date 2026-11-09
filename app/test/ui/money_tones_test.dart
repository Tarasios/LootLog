/// Gains read as gains in both looks: Standard keeps drawing them in its
/// primary (so its screens are unchanged), Adventure draws them green rather
/// than in its ribbon-red primary.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/activity/activity_model.dart';
import 'package:lootlog/features/activity/activity_view.dart';
import 'package:lootlog/game/ui/kit/kit.dart';
import 'package:lootlog/ui/theme.dart';

Future<Color> _gainIn(WidgetTester tester, ThemeData theme) async {
  late Color gain;
  await tester.pumpWidget(
    Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          gain = MoneyTones.gainOf(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return gain;
}

void main() {
  testWidgets('Standard gains stay the primary colour', (tester) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(await _gainIn(tester, theme), theme.colorScheme.primary);
    }
  });

  testWidgets('Adventure gains are green, not the ribbon-red primary', (
    tester,
  ) async {
    final theme = AdventureTheme.build();
    final gain = await _gainIn(tester, theme);
    expect(gain, AdventureTokens.gainInk);
    expect(gain, isNot(theme.colorScheme.primary));
  });

  testWidgets('the activity feed draws a gift in the gain colour', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AdventureTheme.build(),
        home: Scaffold(
          body: ActivityFeedView(
            items: [
              ActivityItem(
                eventId: 'gift',
                kind: ActivityKind.gift,
                userId: 'alex',
                occurredAt: DateTime.utc(2025, 3, 1),
                title: 'Alex found treasure',
                amountCents: 50000,
                isMine: true,
              ),
            ],
          ),
        ),
      ),
    );
    final amount = tester.widget<Text>(find.text('+\$500.00'));
    expect(amount.style?.color, AdventureTokens.gainInk);
  });
}
