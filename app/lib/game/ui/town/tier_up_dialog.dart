/// The tier-up celebration: on entering the town after it grew into a new
/// tier (`TierReached`), once per device, the tier's name on the ribbon, its
/// line, and a pointer to the gifts already waiting in the inbox (the rules
/// granted them; nothing is granted here). It opens only on entering the
/// town, never mid-session and never over Log purchase (see
/// `town_loop_wiring.dart`).
library;

import 'package:flutter/material.dart';

import '../../domain/game_values.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_framed.dart';
import '../kit/kit.dart';
import 'pennant_strip.dart';
import 'town_loop_view.dart' show fillLine;

class TierUpDialog extends StatelessWidget {
  const TierUpDialog({
    super.key,
    required this.tier,
    required this.lines,
    required this.onClose,
    required this.onOpenBook,
  });

  final TownTier tier;
  final TownGrowthLines lines;
  final VoidCallback onClose;
  final VoidCallback onOpenBook;

  @override
  Widget build(BuildContext context) {
    final name = lines.line(tierNameKey(tier));
    return GameDialog(
      title: name,
      onClose: onClose,
      scene: PennantStrip(rows: tier.index + 1),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.line(tierReachedKey(tier)), style: framedBodyStyle(context)),
          const SizedBox(height: AdventureTokens.gap),
          Text(
            fillLine(lines.line('tier.gifts'), {'tier': name}),
            style: AdventureTokens.amount(context).copyWith(color: AdventureTokens.gainInk),
          ),
        ],
      ),
      actions: [
        WoodButton(label: 'Town book', tone: WoodButtonTone.secondary, onPressed: onOpenBook),
        WoodButton(label: 'Hooray!', onPressed: onClose),
      ],
    );
  }
}

/// Celebrates [tier]; the town book opens when asked.
Future<void> showTierUpDialog(
  BuildContext context, {
  required TownTier tier,
  required TownGrowthLines lines,
  required VoidCallback openBook,
}) async {
  final wantsBook = await showGameDialog<bool>(
    context,
    builder: (dialogContext) => TierUpDialog(
      tier: tier,
      lines: lines,
      onClose: () => Navigator.of(dialogContext).pop(false),
      onOpenBook: () => Navigator.of(dialogContext).pop(true),
    ),
  );
  if (wantsBook == true) openBook();
}
