/// The town's districts wired into the town shell: which district is open,
/// the forest grown around each district's map, the district strip, the
/// picker and its purchase celebration, the slide between districts and a
/// swipe past the map's edge. One district shows at a time; each visit gets
/// a fresh scene sized to its map, and hidden districts are never built.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/game_state.dart';
import '../../domain/town/districts.dart';
import '../../domain/town/town_growth_lines.dart';
import '../../domain/town/town_layout.dart';
import '../../domain/town/town_scatter.dart';
import '../hall_common.dart' show showHallCelebration;
import 'district_picker_dialog.dart';
import 'district_strip.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

/// How long the slide between districts takes.
const Duration kDistrictSlide = Duration(milliseconds: 250);

/// The districts the strip lists: every catalogue district that has a map.
List<DistrictSpec> get stripDistricts => [
  for (final district in kDistricts)
    if (TownLayout.forDistrict(district.id) != null) district,
];

mixin TownDistrictWiring<Shell extends ConsumerStatefulWidget> on ConsumerState<Shell> {
  String _openDistrictId = kOutpostDistrictId;

  /// +1 when the last move went east along the strip, -1 when west.
  int _slideDirection = 1;

  /// The forest around each district, grown once per household seed.
  final Map<String, TownScatter> _scatters = {};
  int? _scatterSeed;

  /// The district on screen.
  String get openDistrictId => _openDistrictId;

  /// The map of the district on screen.
  TownLayout get openLayout => TownLayout.forDistrict(_openDistrictId) ?? TownLayout.standard;

  /// The household seed the forests were grown from.
  int? get scatterSeed => _scatterSeed;

  /// The same trees and bushes around [layout] on every device of the
  /// household.
  TownScatter scatterFor(TownLayout layout, Iterable<String> adultIds) {
    final seed = townScatterSeed(adultIds);
    if (_scatterSeed != seed) {
      _scatterSeed = seed;
      _scatters.clear();
    }
    // The narrow farmland gets a deeper forest, so a wide window never
    // shows past it.
    final border = layout.columns < TownLayout.standard.columns ? 14 : 6;
    return _scatters.putIfAbsent(layout.districtId, () => scatterTown(layout, seed: seed, borderWidth: border));
  }

  /// Opens [districtId] (one the town owns, with a map).
  void openDistrict(String districtId) {
    if (districtId == _openDistrictId || TownLayout.forDistrict(districtId) == null) return;
    final order = [for (final district in stripDistricts) district.id];
    setState(() {
      _slideDirection = order.indexOf(districtId) >= order.indexOf(_openDistrictId) ? 1 : -1;
      _openDistrictId = districtId;
    });
  }

  /// Opens the owned district next to the open one in [direction] (+1 east,
  /// -1 west), if there is one.
  void openNeighbour(HallState town, int direction) {
    final owned = [
      for (final district in stripDistricts)
        if (town.districts.owns(district.id)) district.id,
    ];
    final index = owned.indexOf(_openDistrictId) + direction;
    if (index >= 0 && index < owned.length) openDistrict(owned[index]);
  }

  /// The strip for [town]: owned districts open, the others explain what
  /// opens them through the picker.
  /// With [readOnly] (a neighbour's town) only owned districts show and
  /// there is no picker: nothing is for sale on a visit.
  Widget districtStrip(HallState town, TownGrowthLines lines, {bool readOnly = false}) => DistrictStrip(
    entries: [
      for (final district in stripDistricts)
        if (!readOnly || town.districts.owns(district.id))
        DistrictStripEntry(
          districtId: district.id,
          name: lines.line(districtNameKey(district.id)),
          icon: districtIcon(district.id),
          owned: town.districts.owns(district.id),
          lockedLabel: lines.line(tierNameKey(district.requiredTier)),
        ),
    ],
    openDistrictId: _openDistrictId,
    onSelect: (entry) => entry.owned ? openDistrict(entry.districtId) : openDistrictPicker(),
    onMap: readOnly ? null : openDistrictPicker,
  );

  /// The district picker; a purchase opens the new district and celebrates.
  void openDistrictPicker() => unawaited(
    showDistrictPicker(context, onVisit: openDistrict, onBought: _celebratePurchase),
  );

  void _celebratePurchase(String districtId) {
    if (!mounted) return;
    openDistrict(districtId);
    final lines = ref.read(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    final name = lines.line(districtNameKey(districtId));
    final ownLine = lines.line('district.bought.$districtId');
    unawaited(
      showHallCelebration(
        context,
        sprite: districtPicture(districtId) ?? districtPicture(kOutpostDistrictId)!,
        title: name,
        lines: [ownLine.isNotEmpty ? ownLine : fillLine(lines.line('district.bought'), {'district': name})],
      ),
    );
  }

  /// [scene] keyed by its district, sliding in from the side the player
  /// moved toward while the old district slides out.
  Widget slidingDistrict(Widget scene) => ClipRect(
    child: AnimatedSwitcher(
      duration: kDistrictSlide,
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(_openDistrictId);
        final from = Offset(incoming ? _slideDirection.toDouble() : -_slideDirection.toDouble(), 0);
        return SlideTransition(
          position: Tween<Offset>(begin: from, end: Offset.zero).animate(animation),
          child: child,
        );
      },
      child: KeyedSubtree(key: ValueKey(_openDistrictId), child: scene),
    ),
  );
}
