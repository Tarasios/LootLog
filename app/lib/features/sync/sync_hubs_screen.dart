/// The "Sync & Hubs" screen: host a LAN hub, pair with hubs, and sync on demand.
///
/// Sync is peer-to-peer over the local network with no accounts or servers. A
/// desktop hosts a hub (a small HTTP server); phones and the other desktop pair
/// to it and converge. Everything here is non-blocking — failures surface as a
/// status line and a snackbar, never a modal that stops the household cold.
library;

import 'dart:async';
import 'dart:io';

import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/db/database.dart';
import '../../data/export/event_export.dart';
import '../../data/export/merge_import.dart';
import '../../data/sync/sync_service.dart';
import '../../ui/theme.dart';
import 'pairing_qr.dart';
import 'sync_status.dart';

class SyncHubsScreen extends ConsumerStatefulWidget {
  const SyncHubsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SyncHubsScreen()),
      );

  @override
  ConsumerState<SyncHubsScreen> createState() => _SyncHubsScreenState();
}

class _SyncHubsScreenState extends ConsumerState<SyncHubsScreen> {
  HostedHubInfo? _hosted;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(syncServiceProvider);
    final status = ref.watch(liveSyncStatusProvider);
    final pairedAsync = ref.watch(pairedHubsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync & hubs'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(child: SyncStatusIndicator(status: status)),
          ),
        ],
      ),
      body: service == null
          ? const _NotReady()
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                _hostCard(service),
                const SizedBox(height: AppSpacing.lg),
                _pairedCard(pairedAsync),
                const SizedBox(height: AppSpacing.lg),
                _pairCard(service),
                const SizedBox(height: AppSpacing.lg),
                _backupCard(service),
              ],
            ),
      floatingActionButton: service == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _busy ? null : () => _syncNow(service),
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
    );
  }

  Widget _hostCard(SyncService service) {
    final hosted = _hosted;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host a hub', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Run this device as a hub so your phones (and the other desktop) '
              'can pair and sync over the local network.',
            ),
            const SizedBox(height: AppSpacing.sm),
            if (hosted == null)
              FilledButton.icon(
                onPressed: _busy ? null : () => _startHub(service),
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('Start hub'),
              )
            else ...[
              // The pairing QR (the protocol's {url, pairingSecret} payload):
              // scan it from a phone's "Scan QR" button to pair in one step.
              if (hosted.lanUrls.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm),
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: QrImageView(
                        data: jsonEncode({
                          'url': hosted.lanUrls.first,
                          'pairingSecret': hosted.pairingSecret,
                        }),
                        size: 180,
                      ),
                    ),
                  ),
                ),
              _copyRow('Pairing secret', hosted.pairingSecret),
              for (final url in hosted.lanUrls) _copyRow('Address', url),
              if (hosted.lanUrls.isEmpty)
                _copyRow('Port', hosted.port.toString()),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _stopHub(service),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('Stop hub'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pairedCard(AsyncValue<List<PairedHubRow>> pairedAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paired hubs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            pairedAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Could not load hubs: $e'),
              data: (hubs) => hubs.isEmpty
                  ? const _EmptyHubs()
                  : Column(
                      children: [
                        for (final h in hubs)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.hub_outlined),
                            title: Text(h.name.isEmpty ? h.hubId : h.name),
                            subtitle: Text(h.baseUrl),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pairCard(SyncService service) {
    final urlCtrl = TextEditingController();
    final secretCtrl = TextEditingController();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pair with a hub',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Enter the address and pairing secret shown on the hosting device.',
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'http://192.168.1.20:8787',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: secretCtrl,
              decoration: const InputDecoration(labelText: 'Pairing secret'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _pair(service, urlCtrl.text.trim(),
                          secretCtrl.text.trim()),
                  icon: const Icon(Icons.link),
                  label: const Text('Pair'),
                ),
                if (canScanPairingQr)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _scanAndPair(service),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _scanAndPair(SyncService service) async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPairingQrScreen()),
    );
    if (payload == null || !mounted) return;
    final parsed = parsePairingQr(payload);
    if (parsed == null) {
      _snack("That QR code isn't a LootLog pairing code.");
      return;
    }
    await _pair(service, parsed.url, parsed.pairingSecret);
  }

  Widget _backupCard(SyncService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backup & restore',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'When two devices can’t reach a hub, export a .dbevents.zip and '
              'import it on the other. Import is safe to repeat — events and '
              'receipts are matched by id and content hash, and nothing is ever '
              'overwritten.',
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _export(service),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export all'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _exportSince(service),
                  icon: const Icon(Icons.difference_outlined),
                  label: const Text('Export new'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _import(service),
                  icon: const Icon(Icons.download),
                  label: const Text('Import'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _canShare
                  ? 'Export opens the share sheet — send it to a nearby phone '
                      'with Quick Share, Bluetooth, or any app. “Export new” '
                      'sends only what’s changed since last time.'
                  : 'Export new sends only what’s changed since your last '
                      'export — handy for swapping files back and forth on a trip.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: SelectableText(value)),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            tooltip: 'Copy',
            onPressed: () {
              unawaited(Clipboard.setData(ClipboardData(text: value)));
              _snack('Copied');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _startHub(SyncService service) async {
    setState(() => _busy = true);
    try {
      final info = await service.startHub();
      setState(() => _hosted = info);
    } on Object catch (e) {
      _snack('Could not start hub: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopHub(SyncService service) async {
    setState(() => _busy = true);
    await service.stopHub();
    if (mounted) {
      setState(() {
        _hosted = null;
        _busy = false;
      });
    }
  }

  Future<void> _pair(SyncService service, String url, String secret) async {
    if (url.isEmpty || secret.isEmpty) {
      _snack('Enter both an address and a pairing secret');
      return;
    }
    setState(() => _busy = true);
    try {
      await service.pair(url, secret);
      _snack('Paired and synced');
    } on Object catch (e) {
      _snack('Pairing failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Whether this build can hand a file to the OS share sheet. Android only:
  /// that's where Nearby/Quick Share lives and is the low-effort nearby path.
  /// Desktop saves to a file and copies it over instead.
  bool get _canShare => !kIsWeb && Platform.isAndroid;

  Future<void> _export(SyncService service) async {
    setState(() => _busy = true);
    try {
      final bytes = await service.exportArchive();
      final delivered =
          await _deliverExport(bytes, 'lootlog-backup.dbevents.zip');
      if (delivered) _snack('Exported full backup');
    } on Object catch (e) {
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportSince(SyncService service) async {
    setState(() => _busy = true);
    try {
      final export = await service.exportSinceLastExport();
      if (export == null) {
        _snack('Nothing new since your last export');
        return;
      }
      final delivered =
          await _deliverExport(export.bytes, 'lootlog-changes.dbevents.zip');
      if (delivered) {
        final n = export.eventCount;
        _snack('Exported $n new ${n == 1 ? 'event' : 'events'}');
      }
    } on Object catch (e) {
      _snack('Export failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Delivers export [bytes] to the user. On Android this opens the OS share
  /// sheet (Nearby/Quick Share, Bluetooth, messaging…) with the file staged in
  /// the cache dir; elsewhere it saves to a chosen location. Returns false if
  /// the user cancelled.
  Future<bool> _deliverExport(List<int> bytes, String name) async {
    if (_canShare) {
      // share_plus needs a real file path; stage it in the cache dir. It ships
      // its own FileProvider, so no Android manifest wiring is required.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/zip')],
          subject: name,
          text: 'LootLog data to merge on your other device.',
        ),
      );
      return result.status != ShareResultStatus.dismissed;
    }
    final location = await getSaveLocation(suggestedName: name);
    if (location == null) return false;
    final data = XFile.fromData(
      Uint8List.fromList(bytes),
      mimeType: 'application/zip',
      name: name,
    );
    await data.saveTo(location.path);
    return true;
  }

  Future<void> _import(SyncService service) async {
    const group = XTypeGroup(
      label: 'LootLog backup',
      extensions: ['zip', 'dbevents'],
    );
    final file = await openFile(acceptedTypeGroups: [group]);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await file.readAsBytes();
      // Preview first: parse and verify the file, count what's new vs already
      // present, and let the user confirm before anything is written.
      final prepared = file.name.endsWith('.dbevents')
          ? await service.prepareImportJsonl(String.fromCharCodes(bytes))
          : await service.prepareImportArchive(bytes);
      if (!mounted) return;
      final proceed = await _confirmImport(prepared.preview);
      if (proceed != true) {
        _snack('Import cancelled');
        return;
      }
      final applied = await service.applyImport(prepared);
      _snack(applied.isNoOp
          ? 'Already up to date — nothing to add'
          : 'Imported: ${applied.describe()}');
    } on BlobIntegrityException {
      // A receipt's bytes didn't match its hash — a corrupt or tampered file.
      _snack('Import blocked: a receipt in this file is corrupt or tampered.');
    } on ImportException {
      _snack("Import failed: this file isn't a valid LootLog backup.");
    } on FileSystemException {
      _snack('Import failed: could not read that file.');
    } on Object catch (e) {
      _snack('Import failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Shows the merge preview and asks the user to confirm the import.
  Future<bool?> _confirmImport(MergePreview preview) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import this file?'),
        content: Text(
          preview.isNoOp
              ? 'This file has nothing new — every event and receipt is '
                  'already on this device.'
              : '${preview.describe()}.\n\nImporting only adds what\'s '
                  'missing; nothing is ever overwritten.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(preview.isNoOp ? 'OK' : 'Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncNow(SyncService service) async {
    setState(() => _busy = true);
    try {
      final result = await service.syncNow();
      _snack(result.allOk
          ? 'Synced (${result.pulled} in, ${result.pushed} out)'
          : 'Some hubs were unreachable');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyHubs extends StatelessWidget {
  const _EmptyHubs();

  /// The one download link that always points at the newest desktop build.
  static const _releasesUrl =
      'github.com/Tarasios/LootLog/releases/latest';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPhone = !kIsWeb && Platform.isAndroid;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No hubs paired yet. This device works fully on its own.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
          if (isPhone) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tip: install the free desktop app on a home computer to get an '
              'always-on hub — automatic backups of every phone, plus the '
              'receipt library. Download it (Windows or Linux) at '
              '$_releasesUrl, start a hub there, then scan its QR code here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy download link'),
              onPressed: () {
                unawaited(Clipboard.setData(
                    const ClipboardData(text: 'https://$_releasesUrl')));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      const SnackBar(content: Text('Link copied')));
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _NotReady extends StatelessWidget {
  const _NotReady();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Finish first-run setup to enable sync.'),
        ),
      );
}
