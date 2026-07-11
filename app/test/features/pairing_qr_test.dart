import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/features/sync/pairing_qr.dart';

void main() {
  test('parses a valid pairing payload', () {
    final p = parsePairingQr(
        '{"url":"http://192.168.1.20:8787","pairingSecret":"abc123"}');
    expect(p, isNotNull);
    expect(p!.url, 'http://192.168.1.20:8787');
    expect(p.pairingSecret, 'abc123');
  });

  test('rejects non-JSON', () {
    expect(parsePairingQr('WIFI:S:MyNetwork;;'), isNull);
  });

  test('rejects JSON that is not an object', () {
    expect(parsePairingQr('[1,2,3]'), isNull);
  });

  test('rejects missing or non-string fields', () {
    expect(parsePairingQr('{"url":"http://x"}'), isNull);
    expect(parsePairingQr('{"pairingSecret":"s"}'), isNull);
    expect(parsePairingQr('{"url":7,"pairingSecret":"s"}'), isNull);
  });

  test('rejects empty fields', () {
    expect(parsePairingQr('{"url":"","pairingSecret":"s"}'), isNull);
    expect(parsePairingQr('{"url":"http://x","pairingSecret":""}'), isNull);
  });
}
