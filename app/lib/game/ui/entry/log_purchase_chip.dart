/// One destination in the Adventure log-purchase dialog: a parchment card
/// with a swatch in its main category's colour (or, for destinations without
/// one, a colour for its kind) carrying the kind's icon, the name in the pixel
/// font, and what is left in the default face. Tapping it logs the purchase.
library;

import 'package:flutter/material.dart';

import '../../../features/entry/charge_choice.dart';
import '../../../features/entry/charge_picker.dart' show chargeKindIcon;
import '../kit/kit.dart';

/// The swatch's square size.
const double _kSwatchSize = 28;

class LogPurchaseChip extends StatelessWidget {
  const LogPurchaseChip({
    super.key,
    required this.choice,
    required this.onTap,
    required this.width,
  });

  final ChargeChoice choice;
  final VoidCallback onTap;

  /// Every chip in the dialog shares one width, so they line up in columns.
  final double width;

  /// The swatch colour: the main category's, else one per kind.
  Color get _swatchColor {
    final colorArgb = choice.colorArgb;
    if (colorArgb != null) return Color(colorArgb);
    return switch (choice.kind) {
      ChargeGroupKind.personalSlice => AdventureTokens.gem,
      ChargeGroupKind.groupSlice => AdventureTokens.hpGreen,
      ChargeGroupKind.vault => AdventureTokens.gold,
      ChargeGroupKind.quest => AdventureTokens.ribbon,
      ChargeGroupKind.emergency => AdventureTokens.hpRed,
      ChargeGroupKind.vacation => AdventureTokens.hpBlue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = choice.subtitle;
    return SizedBox(
      width: width,
      child: ParchmentCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _kSwatchSize,
              height: _kSwatchSize,
              decoration: BoxDecoration(
                color: _swatchColor,
                border: Border.all(color: AdventureTokens.woodDark, width: 2),
              ),
              child: Icon(
                chargeKindIcon(choice.kind),
                size: 16,
                color: AdventureTokens.parchment,
              ),
            ),
            const SizedBox(width: AdventureTokens.gap),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    choice.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AdventureTokens.label(context),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdventureTokens.amount(context).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: AdventureTokens.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
