part of '../pixel_adventure_view.dart';

/// The scrolling adventure log.
extension _AdventureLogPanel on PixelAdventureView {
  Widget _logPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PixelPanel(
      title: 'Adventure Log',
      accent: scheme.secondary,
      fill: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (encouragement?.isNotEmpty == true) ...[
            Text(
              encouragement!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Expanded(
            child: log.isEmpty
                ? Text(
                    'The tale has not yet begun. Strike a monster to open it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: log.length,
                    itemBuilder: (context, i) => _logLine(context, log[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logLine(BuildContext context, LogEntry entry) {
    final style = toneStyle(context, entry.tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 14, color: style.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.line,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: entry.tone == LogTone.ransack
                        ? FontWeight.w800
                        : FontWeight.w400,
                    color: entry.tone == LogTone.ransack ? style.color : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
