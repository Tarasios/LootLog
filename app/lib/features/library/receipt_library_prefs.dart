/// Device-local persistence for the receipt-library root folder.
///
/// The chosen root is a per-device projection setting, not household data, so it
/// is stored in a tiny file in the app documents directory rather than the event
/// log. [maybeProjectReceiptLibrary] is the hook a future sync cycle calls to
/// re-mirror receipts after every sync; the settings screen also calls it on
/// demand.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/library/receipt_library.dart';
import '../../data/providers.dart';

Future<File> _rootFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'receipt_library_root.txt'));
}

/// Loads the configured receipt-library root, or null if none is set.
Future<String?> loadReceiptLibraryRoot() async {
  final f = await _rootFile();
  // Small device-local prefs file; a synchronous read is fine and avoids the
  // slow-async-io lint.
  if (!f.existsSync()) return null;
  final s = f.readAsStringSync().trim();
  return s.isEmpty ? null : s;
}

/// Persists (or clears, when [path] is null) the receipt-library root.
Future<void> saveReceiptLibraryRoot(String? path) async {
  final f = await _rootFile();
  f.writeAsStringSync(path ?? '', flush: true);
}

/// Projects the receipt library to the configured root if one is set. Safe to
/// call after every sync and on demand; a no-op when no root is configured.
/// Returns the number of files written, or null when there was no root.
Future<int?> maybeProjectReceiptLibrary(Ref ref) async {
  final root = await loadReceiptLibraryRoot();
  if (root == null) return null;
  final state = ref.read(householdStateProvider).value;
  if (state == null) return null;
  final blobs = ref.read(blobStoreProvider);
  final written = await projectReceiptLibrary(root, state, blobs);
  return written.length;
}
