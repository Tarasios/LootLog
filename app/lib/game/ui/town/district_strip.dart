/// The district strip: a row of compact wood buttons, one per district the
/// town can walk into, for moving around the town. The open district is
/// named; the others are icon-only, and the next district the town does not
/// own yet is a padlock (its tier is in its tooltip and the picker). A last
/// "map" button opens the district picker. Past four districts the strip
/// scrolls sideways rather than squeeze its tap targets. On a phone it sits just above Log purchase, in thumb reach; on a
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
  'castleHill' => Icons.fort,
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

  /// More entries than this scroll sideways instead of squeezing: icon
  /// buttons cannot shrink below their tap size.
  static const int _maxFitted = 4;

  @override
  Widget build(BuildContext context) {
    if (entries.length <= _maxFitted) return _row(scrolls: false);
    return SingleChildScrollView(
      key: const ValueKey('district-strip-scroll'),
      scrollDirection: Axis.horizontal,
      child: _row(scrolls: true),
    );
  }

  Widget _row({required bool scrolls}) => Row(
    key: const ValueKey('district-strip'),
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (index, entry) in entries.indexed) ...[
        if (index > 0) const SizedBox(width: 6),
        if (scrolls)
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: _districtButton(entry))
        else
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
      label: open ? entry.name : '',
      icon: locked ? Icons.lock : entry.icon,
      dense: true,
      tone: open ? WoodButtonTone.primary : WoodButtonTone.secondary,
      semanticsLabel: locked ? '${entry.name}, opens at ${entry.lockedLabel}' : entry.name,
      onPressed: () => onSelect(entry),
    );
  }
}
