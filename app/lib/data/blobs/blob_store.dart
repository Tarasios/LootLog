/// Content-addressed blob storage.
///
/// Receipt images/PDFs and custom sprites are NOT events. They are stored as
/// immutable, content-addressed blobs at `<root>/<sha256>` and referenced from
/// the event log (`ReceiptAttached`, and sprite `sha256`s on `QuestSet`,
/// `PetSet`, `CosmeticSet`). Because the name is the hash, writing the same
/// bytes twice is idempotent and de-duplication is automatic.
///
/// A referenced blob is never deleted: garbage collection only removes blobs
/// that the current event log no longer points at.
library;

// Blob IO is intentionally async so it never blocks the UI isolate; the
// `avoid_slow_async_io` guidance (prefer sync stat calls) does not apply here.
// ignore_for_file: avoid_slow_async_io

import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../domain/event.dart';

/// Stores blobs under a single directory, one file per content hash.
class BlobStore {
  BlobStore(this.root);

  /// The directory blobs live in, e.g. `<documents>/blobs`.
  final Directory root;

  /// Saves [bytes], returning the lowercase hex sha256 that names the blob.
  ///
  /// Idempotent: if a blob with the same hash already exists, the existing file
  /// is left untouched (same content by definition) and its hash returned.
  Future<String> save(List<int> bytes) async {
    final sha = sha256.convert(bytes).toString();
    final file = fileFor(sha);
    if (!await file.exists()) {
      await root.create(recursive: true);
      // Write to a temp file then rename, so a reader never sees a partial blob.
      final tmp = File('${file.path}.tmp-$pid');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    }
    return sha;
  }

  /// Whether a blob with [sha256Hex] exists.
  Future<bool> exists(String sha256Hex) => fileFor(sha256Hex).exists();

  /// Reads the blob named [sha256Hex]. Throws if it does not exist.
  Future<Uint8List> read(String sha256Hex) => fileFor(sha256Hex).readAsBytes();

  /// The on-disk file for a given hash.
  File fileFor(String sha256Hex) => File('${root.path}/$sha256Hex');

  /// Deletes a single blob [sha256Hex], but only if it is not in [referenced].
  ///
  /// Returns true if the blob was deleted, false if it was kept because it is
  /// still referenced (or was already absent).
  Future<bool> delete(String sha256Hex, {required Set<String> referenced}) async {
    if (referenced.contains(sha256Hex)) {
      return false;
    }
    final file = fileFor(sha256Hex);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Deletes the local copy of [sha256Hex] unconditionally.
  ///
  /// This is the receipt-offload path: the CALLER must have verified that
  /// every paired hub holds the blob before calling, so "referenced blobs are
  /// never deleted" still holds for the household as a whole — only this
  /// device's cached copy goes, and it can be fetched back on demand.
  Future<bool> offload(String sha256Hex) async {
    final file = fileFor(sha256Hex);
    if (await file.exists()) {
      await file.delete();
      return true;
    }
    return false;
  }

  /// Removes every stored blob not referenced by [events], returning the hashes
  /// deleted. Referenced blobs — live `ReceiptAttached`s and sprite references —
  /// are always kept.
  Future<List<String>> collectGarbage(Iterable<Event> events) async {
    if (!await root.exists()) {
      return const [];
    }
    final keep = referencedBlobs(events);
    final deleted = <String>[];
    await for (final entity in root.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      if (name.endsWith('.tmp-$pid') || name.contains('.tmp-')) {
        continue; // never treat an in-flight temp file as a blob
      }
      if (!keep.contains(name)) {
        await entity.delete();
        deleted.add(name);
      }
    }
    return deleted;
  }

  /// The set of blob hashes the current event log references and that therefore
  /// must never be garbage-collected:
  ///
  ///  * every receipt `sha256` with a live `ReceiptAttached` (an attach not
  ///    cancelled by a later matching `ReceiptDetached`), and
  ///  * every custom-sprite `sha256` on the latest `QuestSet` / `PetSet`, and
  ///  * any 64-hex `CosmeticSet` value (a cosmetic sprite reference).
  static Set<String> referencedBlobs(Iterable<Event> events) {
    // Order attach/detach chronologically so a detach only cancels a prior
    // attach, mirroring the reducer's per-purchase receipt handling.
    final ordered = events.toList()
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        return c != 0 ? c : a.eventId.compareTo(b.eventId);
      });

    final liveReceipts = <String, Set<String>>{}; // purchaseId -> live shas
    final questSprite = <String, String?>{}; // last-writer-wins per quest
    final petSprite = <String, String?>{}; // last-writer-wins per pet
    final memberSprite = <String, String?>{}; // last-writer-wins per member
    final cosmeticSprites = <String>{};

    for (final e in ordered) {
      switch (e) {
        case ReceiptAttached():
          liveReceipts.putIfAbsent(e.purchaseId, () => {}).add(e.sha256);
        case ReceiptDetached():
          liveReceipts[e.purchaseId]?.remove(e.sha256);
        case QuestSet():
          questSprite[e.questId] = e.customSpriteSha256;
        case PetSet():
          petSprite[e.petId] = e.customSpriteSha256;
        case MemberSet():
          memberSprite[e.memberId] = e.customSpriteSha256;
        case CosmeticSet():
          final v = e.value;
          if (v is String && _isSha256(v)) {
            cosmeticSprites.add(v);
          }
        default:
          break;
      }
    }

    return {
      for (final shas in liveReceipts.values) ...shas,
      for (final s in questSprite.values) ?s,
      for (final s in petSprite.values) ?s,
      for (final s in memberSprite.values) ?s,
      ...cosmeticSprites,
    };
  }

  /// The subset of [referencedBlobs] that are live RECEIPT attachments only —
  /// the candidates for receipt offloading. Sprites are excluded: they render
  /// constantly, so evicting them would refetch on every frame's miss.
  static Set<String> receiptBlobs(Iterable<Event> events) {
    final ordered = events.toList()
      ..sort((a, b) {
        final c = a.occurredAt.compareTo(b.occurredAt);
        return c != 0 ? c : a.eventId.compareTo(b.eventId);
      });
    final live = <String, Set<String>>{};
    for (final e in ordered) {
      switch (e) {
        case ReceiptAttached():
          live.putIfAbsent(e.purchaseId, () => {}).add(e.sha256);
        case ReceiptDetached():
          live[e.purchaseId]?.remove(e.sha256);
        default:
          break;
      }
    }
    return {for (final shas in live.values) ...shas};
  }

  static final RegExp _sha256Re = RegExp(r'^[0-9a-f]{64}$');

  static bool _isSha256(String s) => _sha256Re.hasMatch(s);
}
