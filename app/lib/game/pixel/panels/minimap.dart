part of '../pixel_adventure_view.dart';

/// The year minimap: one tile per floor (month).
extension _MinimapPanel on PixelAdventureView {
  Widget _minimap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = game.currentMonth.month; // 1..12
    return _PixelPanel(
      title: 'Year ${game.currentMonth.year}',
      accent: scheme.tertiary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var monthNumber = 1; monthNumber <= 12; monthNumber++)
            _MinimapTile(
              label: _monthInitials[monthNumber - 1],
              status: monthNumber < current
                  ? _FloorStatus.explored
                  : (monthNumber == current
                      ? _FloorStatus.current
                      : _FloorStatus.locked),
              wounded: monthNumber == current && game.heroWounded,
            ),
        ],
      ),
    );
  }
}

enum _FloorStatus { explored, current, locked }

const List<String> _monthInitials = [
  'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
];

class _MinimapTile extends StatelessWidget {
  const _MinimapTile({
    required this.label,
    required this.status,
    required this.wounded,
  });

  final String label;
  final _FloorStatus status;
  final bool wounded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, border) = switch (status) {
      _FloorStatus.current => wounded
          ? (scheme.error, scheme.onError, scheme.error)
          : (scheme.primary, scheme.onPrimary, scheme.primary),
      _FloorStatus.explored => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          scheme.secondary,
        ),
      _FloorStatus.locked => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          scheme.outlineVariant,
        ),
    };
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: status == _FloorStatus.current
              ? FontWeight.w900
              : FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

// ===========================================================================
// Writ row (withdrawal awaiting a signature).
// ===========================================================================
