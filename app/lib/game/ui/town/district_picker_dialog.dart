/// The district picker, from the strip's map button: one card per district
/// in the catalogue with its picture, what it adds, and either a way in
/// (owned), its price and a Buy button (for sale), the tier that opens it,
/// or, for a district a later stage brings, a promise (never a price of 0).
/// Buying runs the real `buyDistrict` command; the shell then opens the new
/// district and celebrates it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../assets/pack_sprite.dart';
import '../../data/game_providers.dart';
import '../../domain/game_values.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/town_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../../domain/town/town_layout.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';
import 'district_strip.dart' show districtIcon;
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

/// The picture on a district's card, or null to draw its icon instead.
AssetKey? districtPicture(String districtId) => switch (districtId) {
  kOutpostDistrictId => GameAssetKeys.building(BuildingType.centralHall, 1),
  kFarmlandDistrictId => GameAssetKeys.farmBuilding(FarmBuildingType.farm, 2),
  _ => null,
};

/// Opens the picker. [onVisit] opens an owned district; [onBought] follows a
/// purchase (the picker has closed by then).
Future<void> showDistrictPicker(
  BuildContext context, {
  required void Function(String districtId) onVisit,
  required void Function(String districtId) onBought,
}) =>
    showGameDialog<void>(
      context,
      builder: (dialogContext) => DistrictPickerDialog(
        close: () => Navigator.of(dialogContext).pop(),
        onVisit: onVisit,
        onBought: onBought,
      ),
    );

class DistrictPickerDialog extends ConsumerWidget {
  const DistrictPickerDialog({super.key, required this.close, required this.onVisit, required this.onBought});

  final VoidCallback close;
  final void Function(String districtId) onVisit;
  final void Function(String districtId) onBought;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId;
    final clock = ref.watch(gameClockProvider);
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final book = townBook(game, meId ?? '', clock.now());
    Future<void> buy(String districtId) async {
      final result = await runHallCommand(context, ref, (service) => service.buyDistrict(districtId));
      if (result == null || !result.accepted) return;
      close();
      onBought(districtId);
    }

    return GameDialog(
      title: lines.line('picker.title'),
      onClose: close,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lines.line('picker.intro'), style: framedBodyStyle(context)),
          for (final listing in book.districts) ...[
            const SizedBox(height: AdventureTokens.gap),
            _DistrictCard(
              listing: listing,
              lines: lines,
              rejection: listing.forSale
                  ? previewRejection(game, meId, clock, (commands) => commands.buyDistrict(listing.spec.id))
                  : null,
              voice: voice,
              onBuy: () => buy(listing.spec.id),
              onVisit: () {
                close();
                onVisit(listing.spec.id);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DistrictCard extends StatelessWidget {
  const _DistrictCard({
    required this.listing,
    required this.lines,
    required this.rejection,
    required this.voice,
    required this.onBuy,
    required this.onVisit,
  });

  final DistrictListing listing;
  final TownGrowthLines lines;
  final GameRejection? rejection;
  final HallVoice voice;
  final VoidCallback onBuy;
  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    final spec = listing.spec;
    final picture = districtPicture(spec.id);
    final tierName = lines.line(tierNameKey(spec.requiredTier));
    return InsetWell(
      key: ValueKey('district-card-${spec.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Center(
              child: picture == null
                  ? Icon(districtIcon(spec.id), size: 40, color: AdventureTokens.inkMuted)
                  : PackSprite(assetKey: picture, scale: 2),
            ),
          ),
          const SizedBox(width: AdventureTokens.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lines.line(districtNameKey(spec.id)), style: AdventureTokens.label(context)),
                const SizedBox(height: 2),
                Text(lines.line(districtBlurbKey(spec.id)), style: framedBodyStyle(context)),
                const SizedBox(height: 4),
                ..._status(context, tierName),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _status(BuildContext context, String tierName) {
    final spec = listing.spec;
    if (listing.owned) {
      return [
        Text(lines.line('district.owned'), style: framedMutedStyle(context)),
        if (TownLayout.forDistrict(spec.id) != null)
          Align(
            alignment: Alignment.centerLeft,
            child: WoodButton(
              key: ValueKey('district-visit-${spec.id}'),
              label: 'Visit',
              dense: true,
              tone: WoodButtonTone.secondary,
              onPressed: onVisit,
            ),
          ),
      ];
    }
    if (!spec.purchasable) {
      return [
        Text(
          '${fillLine(lines.line('district.opensAt'), {'tier': tierName})} · ${lines.line('district.comingLater')}',
          style: framedMutedStyle(context),
        ),
      ];
    }
    if (!listing.forSale) {
      return [
        Text(fillLine(lines.line('district.opensAt'), {'tier': tierName}), style: framedGateStyle(context)),
        Text(fillLine(lines.line('district.locked'), {'tier': tierName}), style: framedMutedStyle(context)),
      ];
    }
    final rejection = this.rejection;
    return [
      CostLine(spec.price),
      if (rejection != null)
        Text(voice.rejection(rejection), style: framedGateStyle(context)),
      const SizedBox(height: 4),
      Align(
        alignment: Alignment.centerLeft,
        child: WoodButton(
          key: ValueKey('district-buy-${spec.id}'),
          label: 'Buy',
          icon: Icons.add_location_alt,
          dense: true,
          onPressed: rejection == null ? onBuy : null,
        ),
      ),
    ];
  }
}
