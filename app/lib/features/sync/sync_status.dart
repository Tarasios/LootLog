/// The sync status indicator: a pure widget driven by a [SyncStatus]. The live
/// state is produced by `SyncService` and exposed via `liveSyncStatusProvider`
/// (`data/sync/sync_service.dart`); this file owns only the enum and chip so the
/// UI/data split stays clean.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';

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
