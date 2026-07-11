/// Shared hub-pairing QR helpers: the `{url, pairingSecret}` payload parser
/// and the full-screen camera scanner. Used by both the Sync & hubs screen and
/// first-run "Join an existing party".
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Whether this build can scan a pairing QR with the camera. Android only;
/// the desktop side is the one showing the code.
bool get canScanPairingQr => !kIsWeb && Platform.isAndroid;

/// The decoded `{url, pairingSecret}` payload of a hub pairing QR.
class PairingQrPayload {
  const PairingQrPayload({required this.url, required this.pairingSecret});

  final String url;
  final String pairingSecret;
}

/// Parses a scanned string; null when it isn't a LootLog pairing code.
PairingQrPayload? parsePairingQr(String raw) {
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return null;
  }
  if (decoded is! Map) return null;
  final url = decoded['url'];
  final secret = decoded['pairingSecret'];
  if (url is! String || secret is! String) return null;
  if (url.isEmpty || secret.isEmpty) return null;
  return PairingQrPayload(url: url, pairingSecret: secret);
}

/// A full-screen camera scanner for the hub pairing QR. Pops with the raw
/// payload string on the first detected code. Android only (guard with
/// [canScanPairingQr]); fully on-device, no network involved.
class ScanPairingQrScreen extends StatefulWidget {
  const ScanPairingQrScreen({super.key});

  @override
  State<ScanPairingQrScreen> createState() => _ScanPairingQrScreenState();
}

class _ScanPairingQrScreenState extends State<ScanPairingQrScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan the hub\'s QR code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final code in capture.barcodes) {
            final value = code.rawValue;
            if (value != null && value.isNotEmpty) {
              _done = true;
              Navigator.of(context).pop(value);
              return;
            }
          }
        },
      ),
    );
  }
}
