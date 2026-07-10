/// Receipt offloading: a device-local, opt-in space saver for phones.
///
/// When enabled, a sync cycle that confirms a receipt blob is held by EVERY
/// paired hub deletes the local copy. The receipt itself is untouched — the
/// `ReceiptAttached` event, the hubs' copies, and the desktop receipt library
/// all keep it — and viewing the receipt fetches the bytes back from a hub on
/// demand. Offloaded hashes are remembered here so the next pull cycle does
/// not immediately re-download what was deliberately removed.
///
/// This is a per-device storage preference, not household data, so — like the
/// skin choice — it lives in tiny files in the app documents directory rather
/// than the event log.
library;

// File IO here is tiny and deliberate; async keeps it off the UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// What this device does with receipt images.
enum ReceiptStorageMode {
  /// Keep every receipt image on this device (the default).
  keep,

  /// Delete local copies once every paired hub confirms holding them;
  /// fetch back on demand.
  offload,

  /// Don't store receipt images at all: the camera is used for the OCR
  /// prefill only, and nothing is attached to the purchase.
  none,
}

/// File-backed receipt-storage mode + set of deliberately-offloaded hashes.
class ReceiptOffloadStore {
  ReceiptOffloadStore({Future<Directory> Function()? dir})
      : _dir = dir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _dir;

  Future<File> _settingFile() async =>
      File(p.join((await _dir()).path, 'receipt_offload.txt'));

  Future<File> _shaFile() async =>
      File(p.join((await _dir()).path, 'offloaded_receipts.txt'));

  /// The device's receipt-storage mode. 'on'/'off' are the legacy values of
  /// the original two-state switch.
  Future<ReceiptStorageMode> mode() async {
    final f = await _settingFile();
    if (!await f.exists()) return ReceiptStorageMode.keep;
    return switch ((await f.readAsString()).trim()) {
      'on' || 'offload' => ReceiptStorageMode.offload,
      'none' => ReceiptStorageMode.none,
      _ => ReceiptStorageMode.keep,
    };
  }

  Future<void> setMode(ReceiptStorageMode value) async {
    final f = await _settingFile();
    await f.writeAsString(value.name, flush: true);
  }

  /// Whether hub-confirmed offloading is on (the sync-cycle space saver).
  Future<bool> enabled() async => await mode() == ReceiptStorageMode.offload;

  Future<void> setEnabled(bool value) => setMode(
      value ? ReceiptStorageMode.offload : ReceiptStorageMode.keep);

  /// The hashes this device has deliberately offloaded (skipped on pull).
  Future<Set<String>> shas() async {
    final f = await _shaFile();
    if (!await f.exists()) return {};
    return {
      for (final line in (await f.readAsString()).split('\n'))
        if (line.trim().isNotEmpty) line.trim(),
    };
  }

  Future<void> addAll(Iterable<String> newShas) async {
    final all = await shas()
      ..addAll(newShas);
    await _write(all);
  }

  /// Forgets [sha] — called when the blob is fetched back on demand, so the
  /// local copy is treated as present again (and may re-offload later).
  Future<void> remove(String sha) async {
    final all = await shas();
    if (all.remove(sha)) await _write(all);
  }

  Future<void> _write(Set<String> all) async {
    final f = await _shaFile();
    final sorted = all.toList()..sort();
    await f.writeAsString(sorted.join('\n'), flush: true);
  }
}

/// The device-wide offload store.
final receiptOffloadStoreProvider =
    Provider<ReceiptOffloadStore>((ref) => ReceiptOffloadStore());

/// The storage mode as watchable state, for the settings screen.
class ReceiptStorageModeNotifier extends AsyncNotifier<ReceiptStorageMode> {
  @override
  Future<ReceiptStorageMode> build() =>
      ref.watch(receiptOffloadStoreProvider).mode();

  Future<void> set(ReceiptStorageMode value) async {
    await ref.read(receiptOffloadStoreProvider).setMode(value);
    state = AsyncData(value);
  }
}

final receiptStorageModeProvider =
    AsyncNotifierProvider<ReceiptStorageModeNotifier, ReceiptStorageMode>(
        ReceiptStorageModeNotifier.new);
