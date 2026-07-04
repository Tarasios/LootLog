/// Provider-wired OCR flow (receipt-first).
///
/// Capture a photo → run on-device recognition (Android) → show the confirm
/// screen with prefilled, editable fields and the receipt pre-attached → create
/// the purchase and attach the receipt **only** on explicit confirm. On
/// platforms without OCR the same confirm screen is shown with no prefill, so a
/// photographed receipt can still be filed manually.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/actions.dart';
import '../../data/ocr/receipt_parse.dart';
import '../../data/ocr/text_recognizer.dart';
import '../../data/providers.dart';
import '../entry/charge_choice.dart';
import '../entry/expense_entry_view.dart' show formatMoney;
import 'ocr_confirm_view.dart';

/// Captures a receipt photo, scans it, and opens the confirm screen. Returns
/// after the user confirms or discards.
Future<void> captureReceiptAndConfirm(BuildContext context, WidgetRef ref) async {
  final picked = await _pickReceiptPhoto();
  if (picked == null) return;

  final ocr = ref.read(receiptOcrProvider);
  var scan = const ReceiptScan(candidateTotals: []);
  if (ocr.isSupported && picked.path != null) {
    try {
      scan = await ocr.scanImageFile(picked.path!);
    } on Object {
      // Recognition failing is non-fatal: fall through to manual confirm.
      scan = const ReceiptScan(candidateTotals: []);
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => OcrConfirmScreen(scan: scan, receiptBytes: picked.bytes),
    ),
  );
}

class _PickedPhoto {
  const _PickedPhoto({required this.bytes, this.path});
  final Uint8List bytes;
  final String? path;
}

Future<_PickedPhoto?> _pickReceiptPhoto() async {
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (isMobile) {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null) return null;
    return _PickedPhoto(bytes: await x.readAsBytes(), path: x.path);
  }
  const group = XTypeGroup(
    label: 'Receipt image',
    extensions: ['jpg', 'jpeg', 'png', 'webp'],
  );
  final x = await openFile(acceptedTypeGroups: [group]);
  if (x == null) return null;
  return _PickedPhoto(bytes: await x.readAsBytes(), path: x.path);
}

class OcrConfirmScreen extends ConsumerWidget {
  const OcrConfirmScreen({
    super.key,
    required this.scan,
    required this.receiptBytes,
  });

  final ReceiptScan scan;
  final Uint8List receiptBytes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    final actions = ref.watch(householdActionsProvider);

    if (setup == null || state == null || actions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final groups = buildChargeGroups(state, setup.meUserId);

    return OcrConfirmView(
      groups: groups,
      scan: scan,
      receiptThumbnail: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(receiptBytes, fit: BoxFit.cover),
      ),
      onConfirm: (result) async {
        final purchaseId = await actions.addPurchase(
          target: result.choice.target,
          amountCents: result.amountCents,
          merchant: result.merchant,
          occurredAt: result.occurredAt,
        );
        await actions.attachReceiptBytes(
          purchaseId,
          receiptBytes,
          isPdf: false,
        );
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved ${formatMoney(result.amountCents)}'),
            ),
          );
        }
      },
    );
  }
}
