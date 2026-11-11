/// The district strip: a row of compact wood buttons, one per district with
/// a map, for moving around the town. The open district is named; the
/// others are icon-only, and a district the town does not own yet wears a
/// padlock beside its tier's name. A last "map" button opens the district
/// picker. On a phone it sits just above Log purchase, in thumb reach; on a
/// desktop at the top centre under the HUD chips.
library;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// One district on the strip.
class DistrictStripEntry {
  const DistrictStripEntry({
    required this.districtId,
    required this.name,
    required this.icon,
    required this.owned,
    this.lockedLabel = '',
  });

  final String districtId;
  final String name;
  final IconData icon;
  final bool owned;

  /// The tier that opens a district not owned yet ("Hamlet").
  final String lockedLabel;
}

/// The icon a district wears on the strip and in the picker.
IconData districtIcon(String districtId) => switch (districtId) {
  'outpost' => Icons.castle,
  'farmland' => Icons.agriculture,
  'guardPost' => Icons.shield,
  'residential' => Icons.cottage,
  'park' => Icons.park,
  'marketRow' => Icons.storefront,
  _ => Icons.place,
};

class DistrictStrip extends StatelessWidget {
  const DistrictStrip({
    super.key,
    required this.entries,
    required this.openDistrictId,
    required this.onSelect,
    this.onMap,
  });

  final List<DistrictStripEntry> entries;
  final String openDistrictId;

  /// A district was tapped: the shell opens it, or explains a locked one.
  final void Function(DistrictStripEntry entry) onSelect;

  /// Opens the district picker; no map button when null (a visit).
  final VoidCallback? onMap;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('district-strip'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, entry) in entries.indexed) ...[
        if (index > 0) const SizedBox(width: 6),
        Flexible(child: _districtButton(entry)),
      ],
      if (onMap case final onMap?) ...[
        const SizedBox(width: 6),
        WoodButton(
        key: const ValueKey('district-map'),
        label: '',
        icon: Icons.map,
        dense: true,
        tone: WoodButtonTone.secondary,
        semanticsLabel: 'Districts',
        onPressed: onMap,
      ),
      ],
    ],
  );

  Widget _districtButton(DistrictStripEntry entry) {
    final open = entry.districtId == openDistrictId;
    final locked = !entry.owned;
    return WoodButton(
      key: ValueKey('district-${entry.districtId}'),
      label: open ? entry.name : (locked ? entry.lockedLabel : ''),
      icon: locked ? Icons.lock : entry.icon,
      dense: true,
      tone: open ? WoodButtonTone.primary : WoodButtonTone.secondary,
      semanticsLabel: locked ? '${entry.name}, opens at ${entry.lockedLabel}' : entry.name,
      onPressed: () => onSelect(entry),
    );
  }
}
