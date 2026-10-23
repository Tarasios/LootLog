/// Settings → Test receipt scanner: take or pick a photo, run on-device
/// recognition, and see exactly what came back — the raw text, what the
/// parser extracted, how long it took, and any error.
///
/// Read-only by design: it never appends an event and never attaches or
/// stores a blob. The photo is only read by the recognizer. Scanning is
/// Android-only, so elsewhere the screen says so in one line.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/ocr/text_recognizer.dart';
import '../../ui/theme.dart';
import 'scan_diagnostics_view.dart';

/// Returns the file path of a photo from [source], or null when cancelled.
typedef ScannerPhotoPicker = Future<String?> Function(ImageSource source);

Future<String?> _pickPhotoPath(ImageSource source) async =>
    (await ImagePicker().pickImage(source: source))?.path;

/// The one line shown where scanning does not run.
const scannerUnsupportedLine =
    'Receipt scanning runs on Android phones, so it can’t be tested here.';

class ReceiptScannerTestScreen extends ConsumerStatefulWidget {
  const ReceiptScannerTestScreen({
    super.key,
    this.pickPhoto = _pickPhotoPath,
  });

  /// Injectable for tests; the app uses image_picker.
  final ScannerPhotoPicker pickPhoto;

  static Future<void> open(BuildContext context) => Navigator.of(context)
      .push(MaterialPageRoute<void>(
          builder: (_) => const ReceiptScannerTestScreen()));

  @override
  ConsumerState<ReceiptScannerTestScreen> createState() =>
      _ReceiptScannerTestScreenState();
}

class _ReceiptScannerTestScreenState
    extends ConsumerState<ReceiptScannerTestScreen> {
  ReceiptScanOutcome? _outcome;
  String? _pickFailure;
  bool _scanning = false;

  Future<void> _scanFrom(ImageSource source) async {
    setState(() {
      _pickFailure = null;
      _outcome = null;
    });
    final String? photoPath;
    try {
      photoPath = await widget.pickPhoto(source);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _pickFailure =
          "Couldn't open the photo: ${describeRecognizerError(error)}");
      return;
    }
    if (photoPath == null || !mounted) return;
    setState(() => _scanning = true);
    final outcome =
        await ref.read(receiptOcrProvider).scanImageFile(photoPath);
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final supported = ref.watch(receiptOcrProvider).isSupported;
    return Scaffold(
      appBar: AppBar(title: const Text('Test receipt scanner')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: supported
            ? _scannerControls(context)
            : const [Text(scannerUnsupportedLine)],
      ),
    );
  }

  List<Widget> _scannerControls(BuildContext context) => [
        const Text(
          'Scan a receipt to see what the scanner reads. Nothing is saved — '
          'no expense is created and the photo is not kept.',
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: _scanning
                  ? null
                  : () => unawaited(_scanFrom(ImageSource.camera)),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Take a photo'),
            ),
            OutlinedButton.icon(
              onPressed: _scanning
                  ? null
                  : () => unawaited(_scanFrom(ImageSource.gallery)),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Choose a photo'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_scanning) const Center(child: CircularProgressIndicator()),
        if (_pickFailure != null) Text(_pickFailure!),
        if (_outcome != null) ScanDiagnosticsView(outcome: _outcome!),
      ];
}
