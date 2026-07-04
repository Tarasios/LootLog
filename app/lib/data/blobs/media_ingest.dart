/// Ingestion helpers that normalize media before it enters the blob store.
///
/// Receipts: images are re-encoded to JPEG (~85 quality, longest side clamped to
/// 2000px); PDFs are stored byte-for-byte. Sprites: PNG only, at most 1 MiB and
/// at most 128x128, stored as-is so the pixel art is never resampled.
///
/// The transforms and validators here are pure and unit-tested; the `ingest*`
/// wrappers add the single side effect of writing to a [BlobStore].
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'blob_store.dart';

/// Longest-side limit for re-encoded receipt images.
const int kReceiptMaxDimension = 2000;

/// JPEG quality used when re-encoding receipt images.
const int kReceiptJpegQuality = 85;

/// Maximum sprite blob size, in bytes (1 MiB).
const int kSpriteMaxBytes = 1024 * 1024;

/// Maximum sprite dimension on either axis.
const int kSpriteMaxDimension = 128;

/// The outcome of ingesting a blob: what to record on the referencing event.
class IngestedBlob {
  const IngestedBlob({
    required this.sha256,
    required this.mimeType,
    required this.sizeBytes,
  });

  final String sha256;
  final String mimeType;
  final int sizeBytes;
}

/// Thrown when a sprite fails validation (wrong format, too large, or oversized).
class SpriteRejected implements Exception {
  const SpriteRejected(this.message);
  final String message;
  @override
  String toString() => 'SpriteRejected: $message';
}

/// Re-encodes a receipt image to JPEG, downscaling so that neither dimension
/// exceeds [maxDimension] while preserving aspect ratio. Images already within
/// the limit are re-encoded without resizing. Pure: no IO.
///
/// Throws [FormatException] if [bytes] is not a decodable image.
Uint8List reencodeReceiptImage(
  Uint8List bytes, {
  int maxDimension = kReceiptMaxDimension,
  int quality = kReceiptJpegQuality,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    // Some malformed inputs make a format probe read out of bounds rather than
    // cleanly returning null; treat any decode failure as an invalid image.
    decoded = null;
  }
  if (decoded == null) {
    throw const FormatException('Not a decodable image');
  }
  final longest =
      decoded.width >= decoded.height ? decoded.width : decoded.height;
  final resized = longest > maxDimension
      ? (decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxDimension)
          : img.copyResize(decoded, height: maxDimension))
      : decoded;
  return img.encodeJpg(resized, quality: quality);
}

/// Ingests a receipt image: re-encode per [reencodeReceiptImage] then store.
Future<IngestedBlob> ingestReceiptImage(
  Uint8List bytes,
  BlobStore store,
) async {
  final jpeg = reencodeReceiptImage(bytes);
  final sha = await store.save(jpeg);
  return IngestedBlob(
    sha256: sha,
    mimeType: 'image/jpeg',
    sizeBytes: jpeg.length,
  );
}

/// Ingests a receipt PDF: stored byte-for-byte (no re-encoding).
Future<IngestedBlob> ingestReceiptPdf(
  Uint8List bytes,
  BlobStore store,
) async {
  final sha = await store.save(bytes);
  return IngestedBlob(
    sha256: sha,
    mimeType: 'application/pdf',
    sizeBytes: bytes.length,
  );
}

/// The 8-byte PNG signature.
const List<int> _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

/// Validates a sprite: PNG format, at most [kSpriteMaxBytes], at most
/// [kSpriteMaxDimension] on each axis. Pure: no IO. Throws [SpriteRejected] on
/// any violation.
void validateSprite(Uint8List bytes) {
  if (bytes.length > kSpriteMaxBytes) {
    throw SpriteRejected(
      'sprite is ${bytes.length} bytes, over the $kSpriteMaxBytes limit',
    );
  }
  if (bytes.length < _pngSignature.length ||
      !_hasPngSignature(bytes)) {
    throw const SpriteRejected('sprite must be a PNG');
  }
  final decoded = img.decodePng(bytes);
  if (decoded == null) {
    throw const SpriteRejected('sprite is not a decodable PNG');
  }
  if (decoded.width > kSpriteMaxDimension ||
      decoded.height > kSpriteMaxDimension) {
    throw SpriteRejected(
      'sprite is ${decoded.width}x${decoded.height}, over '
      '${kSpriteMaxDimension}x$kSpriteMaxDimension',
    );
  }
}

bool _hasPngSignature(Uint8List bytes) {
  for (var i = 0; i < _pngSignature.length; i++) {
    if (bytes[i] != _pngSignature[i]) {
      return false;
    }
  }
  return true;
}

/// Ingests a sprite: validate per [validateSprite] then store the PNG as-is.
Future<IngestedBlob> ingestSprite(Uint8List pngBytes, BlobStore store) async {
  validateSprite(pngBytes);
  final sha = await store.save(pngBytes);
  return IngestedBlob(
    sha256: sha,
    mimeType: 'image/png',
    sizeBytes: pngBytes.length,
  );
}
