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

/// File-backed switch + set of deliberately-offloaded receipt hashes.
class ReceiptOffloadStore {
  ReceiptOffloadStore({Future<Directory> Function()? dir})
      : _dir = dir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _dir;

  Future<File> _settingFile() async =>
      File(p.join((await _dir()).path, 'receipt_offload.txt'));

  Future<File> _shaFile() async =>
      File(p.join((await _dir()).path, 'offloaded_receipts.txt'));

  /// Whether receipt offloading is on for this device. Off by default.
  Future<bool> enabled() async {
    final f = await _settingFile();
    if (!await f.exists()) return false;
    return (await f.readAsString()).trim() == 'on';
  }

  Future<void> setEnabled(bool value) async {
    final f = await _settingFile();
    await f.writeAsString(value ? 'on' : 'off', flush: true);
  }

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

/// The offload switch as watchable state, for the settings screen.
class ReceiptOffloadEnabled extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(receiptOffloadStoreProvider).enabled();

  Future<void> set(bool value) async {
    await ref.read(receiptOffloadStoreProvider).setEnabled(value);
    state = AsyncData(value);
  }
}

final receiptOffloadEnabledProvider =
    AsyncNotifierProvider<ReceiptOffloadEnabled, bool>(
        ReceiptOffloadEnabled.new);
