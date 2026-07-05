/// The sync status indicator. Multi-hub sync is a later phase; until it lands
/// this surfaces a truthful "local only" state. The indicator is a pure widget
/// driven by a [SyncStatus], so it drops straight into the dashboard now and the
/// sync client can feed it a live status later without touching the UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';

/// The current sync status. Multi-hub sync is a later phase; until it lands the
/// household runs local-only, which this reports truthfully. The sync client
/// will override this provider with a live status.
final syncStatusProvider =
    Provider<SyncStatus>((ref) => SyncStatus.localOnly);

/// The coarse state of local-network sync, as the status chip presents it.
enum SyncStatus {
  /// No hubs paired — everything works, nothing is being shared yet.
  localOnly,

  /// Paired and reachable; the last cycle converged.
  synced,

  /// A sync cycle is in flight.
  syncing,

  /// Paired but the last cycle could not reach a hub. Silent-but-visible.
  offline,
}

extension SyncStatusLabel on SyncStatus {
  String get label => switch (this) {
        SyncStatus.localOnly => 'Local only',
        SyncStatus.synced => 'Synced',
        SyncStatus.syncing => 'Syncing…',
        SyncStatus.offline => 'Offline',
      };

  IconData get icon => switch (this) {
        SyncStatus.localOnly => Icons.cloud_off_outlined,
        SyncStatus.synced => Icons.cloud_done_outlined,
        SyncStatus.syncing => Icons.cloud_sync_outlined,
        SyncStatus.offline => Icons.cloud_off_outlined,
      };
}

/// A small, non-blocking status chip. Failures are visible here, never in a
/// dialog.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, required this.status});

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warn = status == SyncStatus.offline;
    final fg = warn ? scheme.error : scheme.onSurfaceVariant;
    return Semantics(
      label: 'Sync status: ${status.label}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 16, color: fg),
          const SizedBox(width: AppSpacing.xs),
          Text(
            status.label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
