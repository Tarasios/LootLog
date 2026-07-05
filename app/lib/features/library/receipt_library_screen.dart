/// Receipt library settings (desktop only): choose a root folder and project the
/// receipt blobs into `<root>/<year>/<slice>/<date>_<merchant>_<amount>.<ext>` on
/// demand. The folder is a regenerable projection — never read back as data — so
/// this screen only writes to it.
library;

import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/library/receipt_library.dart';
import '../../data/providers.dart';
import '../../ui/theme.dart';
import 'receipt_library_prefs.dart';

class ReceiptLibraryScreen extends ConsumerStatefulWidget {
  const ReceiptLibraryScreen({super.key});

  @override
  ConsumerState<ReceiptLibraryScreen> createState() =>
      _ReceiptLibraryScreenState();
}

class _ReceiptLibraryScreenState extends ConsumerState<ReceiptLibraryScreen> {
  String? _root;
  bool _loading = true;
  bool _busy = false;
  String? _lastResult;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final root = await loadReceiptLibraryRoot();
    if (mounted) {
      setState(() {
        _root = root;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final plannedCount = () {
      final state = ref.watch(householdStateProvider).value;
      if (state == null) return 0;
      return planReceiptLibrary(state).length;
    }();

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt library')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Text(
                  'The receipt library mirrors your receipts into an ordinary '
                  'folder, organized by year, slice, and date. It is a '
                  'regenerable projection: rebuilding always produces the same '
                  'files, and any edits you make inside the folder are '
                  'overwritten.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Root folder', style: AppText.sectionLabel(context)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _root ?? 'Not set',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy ? null : _chooseFolder,
                      icon: const Icon(Icons.folder_open, size: 18),
                      label: const Text('Choose folder'),
                    ),
                    if (_root != null)
                      TextButton(
                        onPressed: _busy ? null : _clearFolder,
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('$plannedCount receipt files will be written.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _root == null || _busy ? null : _projectNow,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(_busy ? 'Projecting…' : 'Project now'),
                ),
                if (_lastResult != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(_lastResult!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
    );
  }

  Future<void> _chooseFolder() async {
    final dir = await getDirectoryPath();
    if (dir == null) return;
    await saveReceiptLibraryRoot(dir);
    if (mounted) setState(() => _root = dir);
  }

  Future<void> _clearFolder() async {
    await saveReceiptLibraryRoot(null);
    if (mounted) setState(() => _root = null);
  }

  Future<void> _projectNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final root = _root;
    final state = ref.read(householdStateProvider).value;
    final blobs = ref.read(blobStoreProvider);
    if (root == null || state == null) return;
    setState(() => _busy = true);
    try {
      final written = await projectReceiptLibrary(root, state, blobs);
      setState(() => _lastResult = 'Wrote ${written.length} files.');
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Projection failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
