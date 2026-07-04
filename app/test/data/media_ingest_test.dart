import 'dart:io';
import 'dart:typed_data';

import 'package:duobudget/data/blobs/blob_store.dart';
import 'package:duobudget/data/blobs/media_ingest.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List _png(int w, int h) => img.encodePng(img.Image(width: w, height: h));

void main() {
  group('reencodeReceiptImage', () {
    test('downscales so the longest side is at most maxDimension', () {
      // 3000x1000 landscape -> width clamps to 2000, aspect preserved.
      final out = reencodeReceiptImage(_png(3000, 1000));
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 2000);
      expect(decoded.height, 667); // round(1000 * 2000/3000)
    });

    test('clamps the taller side for portrait images', () {
      final out = reencodeReceiptImage(_png(1000, 4000));
      final decoded = img.decodeImage(out)!;
      expect(decoded.height, 2000);
      expect(decoded.width, 500);
    });

    test('leaves within-limit images at their original size (as JPEG)', () {
      final out = reencodeReceiptImage(_png(120, 80));
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 120);
      expect(decoded.height, 80);
      // JPEG magic bytes.
      expect(out[0], 0xFF);
      expect(out[1], 0xD8);
    });

    test('respects a custom maxDimension', () {
      final out = reencodeReceiptImage(_png(500, 250), maxDimension: 100);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 100);
      expect(decoded.height, 50);
    });

    test('throws on undecodable bytes', () {
      expect(
        () => reencodeReceiptImage(Uint8List.fromList([0, 1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('ingest helpers', () {
    late Directory tmp;
    late BlobStore store;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('ingest_test');
      store = BlobStore(Directory('${tmp.path}/blobs'));
    });
    tearDown(() async {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
    });

    test('ingestReceiptImage stores a JPEG and reports its metadata', () async {
      final result = await ingestReceiptImage(_png(2500, 2500), store);
      expect(result.mimeType, 'image/jpeg');
      final stored = await store.read(result.sha256);
      expect(stored, hasLength(result.sizeBytes));
      final decoded = img.decodeImage(stored)!;
      expect(decoded.width, 2000);
      expect(decoded.height, 2000);
    });

    test('ingestReceiptPdf stores the bytes unchanged', () async {
      final pdf = Uint8List.fromList([37, 80, 68, 70, 1, 2, 3, 4]); // %PDF...
      final result = await ingestReceiptPdf(pdf, store);
      expect(result.mimeType, 'application/pdf');
      expect(result.sizeBytes, pdf.length);
      expect(await store.read(result.sha256), pdf);
    });
  });

  group('validateSprite', () {
    test('accepts a small PNG', () {
      expect(() => validateSprite(_png(64, 64)), returnsNormally);
      expect(() => validateSprite(_png(128, 128)), returnsNormally);
    });

    test('rejects PNGs larger than 128 on either axis', () {
      expect(() => validateSprite(_png(200, 64)), throwsA(isA<SpriteRejected>()));
      expect(() => validateSprite(_png(64, 129)), throwsA(isA<SpriteRejected>()));
    });

    test('rejects blobs over the 1 MiB size cap', () {
      // Size is checked before decoding, so a large buffer fails fast.
      final tooBig = Uint8List(kSpriteMaxBytes + 1);
      expect(() => validateSprite(tooBig), throwsA(isA<SpriteRejected>()));
    });

    test('rejects non-PNG formats', () {
      final jpeg = img.encodeJpg(img.Image(width: 32, height: 32));
      expect(() => validateSprite(jpeg), throwsA(isA<SpriteRejected>()));
    });

    test('ingestSprite stores the PNG byte-for-byte', () async {
      final tmp = await Directory.systemTemp.createTemp('sprite_test');
      addTearDown(() async => tmp.delete(recursive: true));
      final store = BlobStore(Directory('${tmp.path}/blobs'));

      final png = _png(32, 32);
      final result = await ingestSprite(png, store);
      expect(result.mimeType, 'image/png');
      expect(result.sizeBytes, png.length);
      expect(await store.read(result.sha256), png);
    });
  });
}
