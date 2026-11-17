/// The district strip: a row of compact wood buttons, one per district the
/// town can walk into, for moving around the town. The open district is
/// named; the others are icon-only, and the next district the town does not
/// own yet is a padlock (its tier is in its tooltip and the picker). A last
/// "map" button opens the district picker. Past four districts the
/// districts scroll sideways (the map button stays put) rather than squeeze
/// their tap targets, and the open one is scrolled fully into view. On a phone it sits just above Log purchase, in thumb reach; on a
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
    String? shortName,
  }) : _shortName = shortName;

  final String districtId;
  final String name;

  /// The open district's label on the strip ("Homes" for the Residential
  /// Quarter); the picker and headers keep [name].
  String get shortName => _shortName == null || _shortName.isEmpty ? name : _shortName;
  final String? _shortName;
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

class DistrictStrip extends StatefulWidget {
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
  static const int maxFitted = 4;

  @override
  State<DistrictStrip> createState() => _DistrictStripState();
}

class _DistrictStripState extends State<DistrictStrip> {
  /// The open district's button, scrolled fully into view when it changes.
  final GlobalKey _openButton = GlobalKey();
  String? _scrolledTo;

  /// Room kept at either end of the scrolling row, so the end buttons sit
  /// clear of the edge.
  static const double _edge = 4;

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.length <= DistrictStrip.maxFitted) return _row(scrolls: false);
    if (_scrolledTo != widget.openDistrictId) {
      _scrolledTo = widget.openDistrictId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _openButton.currentContext;
        if (target != null && target.mounted) Scrollable.ensureVisible(target, alignment: 0.5);
      });
    }
    // The map button stays put; only the districts scroll.
    return Row(
      key: const ValueKey('district-strip'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            key: const ValueKey('district-strip-scroll'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _edge),
            child: Row(mainAxisSize: MainAxisSize.min, children: _districtButtons(scrolls: true)),
          ),
        ),
        ..._mapButton(),
      ],
    );
  }

  Widget _row({required bool scrolls}) => Row(
    key: const ValueKey('district-strip'),
    mainAxisSize: MainAxisSize.min,
    children: [..._districtButtons(scrolls: scrolls), ..._mapButton()],
  );

  List<Widget> _districtButtons({required bool scrolls}) => [
    for (final (index, entry) in widget.entries.indexed) ...[
      if (index > 0) const SizedBox(width: 6),
      if (scrolls)
        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: _districtButton(entry))
      else
        Flexible(child: _districtButton(entry)),
    ],
  ];

  List<Widget> _mapButton() => [
    if (widget.onMap case final onMap?) ...[
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
  ];

  Widget _districtButton(DistrictStripEntry entry) {
    final open = entry.districtId == widget.openDistrictId;
    final locked = !entry.owned;
    final button = WoodButton(
      key: ValueKey('district-${entry.districtId}'),
      label: open ? entry.shortName : '',
      icon: locked ? Icons.lock : entry.icon,
      dense: true,
      tone: open ? WoodButtonTone.primary : WoodButtonTone.secondary,
      semanticsLabel: locked ? '${entry.name}, opens at ${entry.lockedLabel}' : entry.name,
      onPressed: () => widget.onSelect(entry),
    );
    return open ? KeyedSubtree(key: _openButton, child: button) : button;
  }
}
