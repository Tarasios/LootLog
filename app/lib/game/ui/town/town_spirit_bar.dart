/// The town spirit bar under the HUD's date chip: five pips for Monday to
/// Friday (lit for each weekday logged) and a festival pennant that lights
/// at the weekend. Tapping it explains this week's spirit and the festival
/// it earns ([showTownSpiritDialog]). Small enough to sit beside the
/// treasure chips on a 360 px phone.
library;

import 'package:flutter/material.dart';

import '../../domain/town/town_event_lines.dart';
import '../hall_framed.dart' show framedBodyStyle;
import '../kit/kit.dart';
import 'town_loop_view.dart';

/// The size of one weekday pip.
const double _kPipSize = 12;

class TownSpiritBar extends StatelessWidget {
  const TownSpiritBar({super.key, required this.days, required this.weekend, this.onTap});

  /// Monday to Friday: logged or not.
  final List<bool> days;

  /// The weekend is here: the pennant is lit.
  final bool weekend;
  final VoidCallback? onTap;

  static const List<String> _weekdayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

  @override
  Widget build(BuildContext context) {
    final logged = days.where((day) => day).length;
    final bar = Semantics(
      label: 'Town spirit: $logged of 5 weekdays logged${weekend ? ', festival weekend' : ''}',
      child: PixelFrame(
        assetKey: KitKeys.parchment,
        scale: 1,
        fallbackFill: AdventureTokens.parchment,
        fallbackBorder: AdventureTokens.woodDark,
        padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, lit) in days.indexed) ...[
              if (index > 0) const SizedBox(width: 3),
              _Pip(key: ValueKey('town-spirit-pip-$index'), lit: lit, name: _weekdayNames[index]),
            ],
            const SizedBox(width: 5),
            Icon(
              Icons.flag,
              key: const ValueKey('town-spirit-pennant'),
              size: 18,
              color: weekend ? AdventureTokens.ribbon : AdventureTokens.parchmentDark,
            ),
          ],
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) return bar;
    return KitPressable(
      onPressed: onTap,
      minHitSize: const Size(44, 44),
      builder: (context, pressed) => Transform.translate(offset: Offset(0, pressed ? 1 : 0), child: bar),
    );
  }
}

/// One weekday: a gold square when logged, an empty well otherwise.
class _Pip extends StatelessWidget {
  const _Pip({super.key, required this.lit, required this.name});

  final bool lit;
  final String name;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '$name${lit ? ': logged' : ''}',
    excludeFromSemantics: true,
    child: SizedBox.square(
      dimension: _kPipSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: lit ? AdventureTokens.gold : AdventureTokens.parchmentDark,
          border: Border.all(color: AdventureTokens.woodDark),
        ),
      ),
    ),
  );
}

/// Explains this week's spirit and the festival it earns.
Future<void> showTownSpiritDialog(BuildContext context, TownLoopView view, TownEventLines lines) =>
    showGameDialog<void>(
      context,
      builder: (dialogContext) => GameDialog(
        title: lines.line('spirit.title'),
        onClose: () => Navigator.of(dialogContext).pop(),
        scene: Center(
          child: Transform.scale(
            scale: 2,
            child: TownSpiritBar(days: view.spiritDays, weekend: view.weekend),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, line) in lines.spiritLines(view).indexed)
              Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : AdventureTokens.gap),
                child: Text(line, style: framedBodyStyle(dialogContext)),
              ),
          ],
        ),
        actions: [
          WoodButton(label: 'Close', onPressed: () => Navigator.of(dialogContext).pop()),
        ],
      ),
    );
