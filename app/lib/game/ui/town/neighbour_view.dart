/// The pieces of a visit to a neighbour's town: the visiting HUD (a compact
/// "Visiting <name>" header with Back; Log purchase, which still logs for
/// you; Send a gift and Cheer), the read-only note a tapped plot opens, and
/// the signpost's chooser when several towns lie down the road. Nothing here
/// runs a command except the gift and the cheer.
library;

import 'package:flutter/material.dart';

import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../../domain/town/town_growth_lines.dart';
import '../../domain/town/town_view.dart';
import '../hall_framed.dart';
import '../hall_names.dart';
import '../kit/kit.dart';
import 'hud_insets.dart';
import 'town_hud.dart' show kTownHudCompactWidth;

/// Keeps the HUD clear of the window edge.
const double _kEdge = 12;

/// The HUD while visiting a neighbour's town.
class NeighbourHud extends StatelessWidget {
  const NeighbourHud({
    super.key,
    required this.header,
    required this.onBack,
    required this.onLogPurchase,
    required this.onGift,
    required this.onCheer,
    required this.cheerLabel,
    this.districtStrip,
    this.insets,
  });

  /// Where a phone HUD reports how much of the scene it covers.
  final HudInsets? insets;

  /// "Visiting Sam".
  final String header;
  final VoidCallback onBack;

  /// Logs a purchase for this device's adult, as at home.
  final VoidCallback onLogPurchase;
  final VoidCallback onGift;

  /// Null once today's cheer is sent.
  final VoidCallback? onCheer;
  final String cheerLabel;

  /// The neighbour's districts (owned ones only; nothing to buy here).
  final Widget? districtStrip;

  /// [child], reporting its cover to [insets] on a phone.
  Widget _measured(BuildContext context, Widget child, {required bool top}) {
    final insets = this.insets;
    if (insets == null) return child;
    if (MediaQuery.sizeOf(context).width >= kTownHudCompactWidth) {
      WidgetsBinding.instance.addPostFrameCallback((_) => insets.clear());
      return child;
    }
    final padding = MediaQuery.paddingOf(context);
    return ReportSize(
      onSize: (size) => top
          ? insets.reportTop('visit', size.height + _kEdge + padding.top)
          : insets.setBottom(size.height + _kEdge + padding.bottom),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: [
        Positioned(
          top: _kEdge,
          left: _kEdge,
          right: _kEdge,
          child: _measured(context, top: true, Row(
            children: [
              WoodButton(
                key: const ValueKey('neighbour-back'),
                label: 'Back',
                icon: Icons.arrow_back,
                dense: true,
                tone: WoodButtonTone.secondary,
                onPressed: onBack,
              ),
              const SizedBox(width: AdventureTokens.gap),
              Flexible(
                child: HudChip(
                  key: const ValueKey('neighbour-header'),
                  icon: Icons.signpost,
                  value: header,
                  prose: true,
                  maxWidth: 480,
                ),
              ),
            ],
          )),
        ),
        Positioned(
          left: _kEdge,
          right: _kEdge,
          bottom: _kEdge,
          child: _measured(context, top: false, Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (districtStrip case final strip?) ...[strip, const SizedBox(height: AdventureTokens.gap)],
              HudButton(label: 'Log purchase', icon: Icons.add_shopping_cart, large: true, onPressed: onLogPurchase),
              const SizedBox(height: AdventureTokens.gap),
              Row(
                children: [
                  Flexible(
                    child: WoodButton(
                      key: const ValueKey('neighbour-gift'),
                      label: 'Send a gift',
                      icon: Icons.card_giftcard,
                      onPressed: onGift,
                    ),
                  ),
                  const SizedBox(width: AdventureTokens.gap),
                  Flexible(
                    child: WoodButton(
                      key: const ValueKey('neighbour-cheer'),
                      label: cheerLabel,
                      icon: Icons.celebration,
                      tone: WoodButtonTone.secondary,
                      onPressed: onCheer,
                    ),
                  ),
                ],
              ),
            ],
          )),
        ),
      ],
    ),
  );
}

/// A tapped plot in a neighbour's town: what stands there, read-only.
Future<void> showNeighbourPlotInfo(
  BuildContext context, {
  required TownPlotView plot,
  required String neighbourName,
  required NeighbourLines lines,
  required TownGrowthLines growthLines,
}) {
  final buildingType = plot.buildingType;
  final farmType = plot.farmType;
  final title = buildingType != null
      ? HallNames.building(buildingType)
      : farmType != null
          ? growthLines.line(farmBuildingNameKey(farmType))
          : 'Plot ${plot.plotIndex + 1}';
  final tier = {'tier': '${plot.tier}', 'name': neighbourName};
  final note = !plot.unlocked
      ? lines.line('visit.locked')
      : buildingType == null && farmType == null
          ? lines.line('visit.empty', tier)
          : plot.underConstruction
              ? lines.line('visit.underConstruction', tier)
              : lines.line('visit.building', tier);
  return showGameDialog<void>(
    context,
    builder: (dialogContext) => GameDialog(
      key: const ValueKey('neighbour-plot-info'),
      title: title,
      onClose: () => Navigator.of(dialogContext).pop(),
      body: Text(note, style: framedBodyStyle(dialogContext)),
      actions: [
        WoodButton(
          key: const ValueKey('neighbour-plot-close'),
          label: 'Close',
          tone: WoodButtonTone.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
    ),
  );
}

/// The signpost's chooser: every town down the road with Visit, and the
/// supply caravan's camp (never named, no visit).
Future<void> showSignpostChooser(
  BuildContext context, {
  required List<TownNeighbour> neighbours,
  required NeighbourLines lines,
  required void Function(TownNeighbour neighbour) onVisit,
}) => showGameDialog<void>(
  context,
  builder: (dialogContext) => GameDialog(
    title: lines.line('signpost.title'),
    onClose: () => Navigator.of(dialogContext).pop(),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(lines.line('signpost.body'), style: framedBodyStyle(dialogContext)),
        const SizedBox(height: AdventureTokens.gap),
        for (final neighbour in neighbours.where((n) => n.canVisit))
          Padding(
            padding: const EdgeInsets.only(bottom: AdventureTokens.gap),
            child: Row(
              children: [
                Expanded(child: Text(neighbour.name, style: framedBodyStyle(dialogContext, weight: FontWeight.w700))),
                WoodButton(
                  key: ValueKey('signpost-visit-${neighbour.memberId}'),
                  label: 'Visit',
                  dense: true,
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onVisit(neighbour);
                  },
                ),
              ],
            ),
          ),
        if (neighbours.any((n) => n.isCaravan))
          Text(lines.line('signpost.caravan'), style: framedMutedStyle(dialogContext)),
      ],
    ),
  ),
);
