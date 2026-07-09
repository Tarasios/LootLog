/// The receipt library: a **regenerable projection, never a source of truth**.
///
/// The path/naming logic here is pure and unit-tested. Given the derived
/// [HouseholdState] it produces a deterministic list of relative file paths, one
/// per live receipt, under
/// `<year>/<slice name>/<yyyy-MM-dd>_<merchant or 'receipt'>_<amount>.<ext>`
/// with filesystem-safe sanitization and `_2`-style de-duplication. Rebuilding
/// from scratch produces identical content; the folder is disposable.
///
/// The single side effect — mirroring blobs onto disk under a chosen root — lives
/// in [projectReceiptLibrary], which calls the pure [planReceiptLibrary].
library;

import 'dart:io';

import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';
import '../blobs/blob_store.dart';

/// One planned file in the receipt library: which blob to write, and where
/// (a `/`-joined path relative to the library root).
class ReceiptLibraryEntry {
  const ReceiptLibraryEntry({
    required this.sha256,
    required this.mimeType,
    required this.relativePath,
  });

  final String sha256;
  final String mimeType;

  /// The `/`-separated path relative to the library root, e.g.
  /// `2026/Groceries/2026-07-04_Safeway_42.10.jpg`.
  final String relativePath;

  @override
  bool operator ==(Object other) =>
      other is ReceiptLibraryEntry &&
      other.sha256 == sha256 &&
      other.mimeType == mimeType &&
      other.relativePath == relativePath;

  @override
  int get hashCode => Object.hash(sha256, mimeType, relativePath);

  @override
  String toString() => 'ReceiptLibraryEntry($relativePath <- $sha256)';
}

/// Plans the full receipt-library projection for [state]: one entry per live
/// receipt on every non-voided purchase, in a deterministic order, with
/// `_2`/`_3`… de-duplication applied to colliding paths. Pure — no IO.
List<ReceiptLibraryEntry> planReceiptLibrary(HouseholdState state) {
  // Gather one raw record per (purchase, receipt), independent of iteration
  // order so the projection is stable across machines and runs.
  final raw = <_RawEntry>[];
  for (final p in state.purchases.values) {
    if (p.voided) continue;
    for (final r in p.receipts) {
      raw.add(_RawEntry(
        year: p.month.year,
        folder: _folderFor(state, p.target),
        day: _householdDay(p.occurredAt),
        merchant: p.merchant,
        amountCents: p.amountCents,
        sha256: r.sha256,
        mimeType: r.mimeType,
      ));
    }
  }

  // Deterministic order: by directory, then by intended base name, then by hash
  // as a stable tie-break. De-dup suffixes are then assigned in this order, so
  // the same inputs always yield the same names.
  raw.sort((a, b) {
    final c = a.dir.compareTo(b.dir);
    if (c != 0) return c;
    final n = a.baseName.compareTo(b.baseName);
    if (n != 0) return n;
    return a.sha256.compareTo(b.sha256);
  });

  final usedPaths = <String>{};
  final out = <ReceiptLibraryEntry>[];
  for (final e in raw) {
    final path = _dedup(e.dir, e.stem, e.ext, usedPaths);
    out.add(ReceiptLibraryEntry(
      sha256: e.sha256,
      mimeType: e.mimeType,
      relativePath: path,
    ));
  }
  return out;
}

/// Writes [state]'s receipt-library projection under [rootPath], reading blob
/// bytes from [blobs]. Existing files at target paths are overwritten so user
/// edits are ignored. Returns the list of relative paths written.
///
/// This is the only impure entry point; all path/naming decisions come from the
/// pure [planReceiptLibrary].
Future<List<String>> projectReceiptLibrary(
  String rootPath,
  HouseholdState state,
  BlobStore blobs, {
  ReceiptLibraryFs fs = const ReceiptLibraryFs(),
}) async {
  final plan = planReceiptLibrary(state);
  final written = <String>[];
  for (final entry in plan) {
    if (!await blobs.exists(entry.sha256)) continue;
    final bytes = await blobs.read(entry.sha256);
    await fs.writeFile(rootPath, entry.relativePath, bytes);
    written.add(entry.relativePath);
  }
  return written;
}

/// Thin filesystem seam so [projectReceiptLibrary] stays testable. The default
/// writes to the real filesystem; the pure planner never touches it.
class ReceiptLibraryFs {
  const ReceiptLibraryFs();

  Future<void> writeFile(
    String rootPath,
    String relativePath,
    List<int> bytes,
  ) async {
    final full = '$rootPath/$relativePath';
    final file = File(full);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }
}

// ---- Pure helpers ---------------------------------------------------------

/// The household-timezone calendar day of [instant] as `yyyy-MM-dd`.
String _householdDay(DateTime instant) {
  final u = instant.toUtc();
  final local = u.add(vancouverUtcOffset(u));
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// The folder name for a charge target: slice name, quest name, fund name, or a
/// stable label for the vault. Sanitized to a safe path segment.
String _folderFor(HouseholdState state, ChargeTarget target) {
  final label = switch (target) {
    SliceCharge(:final sliceId) => state.slices[sliceId]?.name ?? 'Slice',
    VaultCharge() => 'Vault',
    QuestCharge(:final questId) => state.quests[questId]?.name ?? 'Quest',
    EmergencyCharge(:final fundId) =>
      state.emergencyFunds[fundId]?.name ?? 'Emergency',
    VacationCharge(:final vacationId) =>
      state.vacations[vacationId]?.name ?? 'Vacation',
  };
  return sanitizeSegment(label, fallback: 'receipts');
}

/// Characters that are unsafe in a path segment across Windows/macOS/Linux.
final RegExp _unsafeChars = RegExp(r'[\\/:*?"<>|\x00-\x1f]');

/// Sanitizes an arbitrary label into a single filesystem-safe path segment:
/// unsafe characters collapse to `_`, surrounding whitespace and dots are
/// trimmed, runs of `_` are collapsed, and an empty result becomes [fallback].
String sanitizeSegment(String input, {String fallback = 'receipt'}) {
  var s = input.replaceAll(_unsafeChars, '_');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  // Strip characters that are legal mid-name but unsafe at the edges.
  s = s.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  s = s.replaceAll(RegExp(r'_+'), '_');
  s = s.replaceAll(RegExp(r'^_+|_+$'), '');
  if (s.isEmpty) return fallback;
  // Guard against absurdly long segments (keep well under common 255-byte caps).
  return s.length > 80 ? s.substring(0, 80) : s;
}

/// Maps a receipt mime type to a lowercase file extension.
String extensionForMime(String mimeType) {
  switch (mimeType.toLowerCase()) {
    case 'image/jpeg':
    case 'image/jpg':
      return 'jpg';
    case 'image/png':
      return 'png';
    case 'application/pdf':
      return 'pdf';
    case 'image/webp':
      return 'webp';
    case 'image/heic':
      return 'heic';
    default:
      final slash = mimeType.lastIndexOf('/');
      final tail = slash >= 0 ? mimeType.substring(slash + 1) : mimeType;
      final safe = tail.replaceAll(RegExp(r'[^a-z0-9]'), '').toLowerCase();
      return safe.isEmpty ? 'bin' : safe;
  }
}

/// Resolves a de-duplicated relative path, appending `_2`, `_3`, … to the stem
/// until the whole path is unused. Records the winner in [used].
String _dedup(String dir, String stem, String ext, Set<String> used) {
  String join(String s) => '$dir/$s.$ext';
  var candidate = join(stem);
  var n = 2;
  while (used.contains(candidate)) {
    candidate = join('${stem}_$n');
    n++;
  }
  used.add(candidate);
  return candidate;
}

/// A pre-sanitization record for one (purchase, receipt) pair.
class _RawEntry {
  _RawEntry({
    required this.year,
    required this.folder,
    required this.day,
    required this.merchant,
    required this.amountCents,
    required this.sha256,
    required this.mimeType,
  });

  final int year;
  final String folder;
  final String day;
  final String? merchant;
  final int amountCents;
  final String sha256;
  final String mimeType;

  String get dir => '$year/$folder';

  String get _merchantPart {
    final m = merchant?.trim() ?? '';
    return m.isEmpty ? 'receipt' : sanitizeSegment(m, fallback: 'receipt');
  }

  /// The base name before extension and before de-dup suffixing.
  String get stem => '${day}_${_merchantPart}_${Money(amountCents).format()}';

  String get ext => extensionForMime(mimeType);

  String get baseName => '$stem.$ext';
}
