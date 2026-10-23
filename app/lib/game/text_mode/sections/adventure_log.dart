part of '../text_adventure_view.dart';

/// The adventure log.
extension _AdventureLogSection on TextAdventureView {
  Widget _logPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Adventure Log',
      icon: Icons.menu_book_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (encouragement?.isNotEmpty == true) ...[
            Text(encouragement!,
                style: monoStyle(context, color: scheme.tertiary)
                    .copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (log.isEmpty)
            Text('The tale has not yet begun. Strike a monster to open it.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            for (final entry in log) _logLine(context, entry),
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
          Icon(style.icon, size: 16, color: style.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(entry.line,
                style: monoStyle(context,
                    weight: entry.tone == LogTone.ransack
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
