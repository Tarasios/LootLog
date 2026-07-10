/// The purchase detail sheet: review and correct one purchase.
///
/// Merchant, note, date, and the (valid-only) shared toggle are editable; the
/// purchase can be voided; receipts can be attached (camera/gallery on mobile,
/// file picker on desktop, multiple allowed), viewed, and detached; and a quiet
/// "Tax deductible" override shows the slice's inherited default. Every edit is
/// an appended event (corrections void-and-re-add), never an in-place mutation.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/actions.dart';
import '../../data/ocr/text_recognizer.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../game/skin_prefs.dart';
import '../../ui/theme.dart';
import '../entry/expense_entry_view.dart' show formatMoney;

/// Shows the detail sheet for [purchaseId]. It tracks live state, so an edit
/// that voids-and-re-adds swaps the sheet over to the corrected purchase.
Future<void> showPurchaseDetailSheet(
  BuildContext context, {
  required String purchaseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => PurchaseDetailSheet(initialPurchaseId: purchaseId),
  );
}

class PurchaseDetailSheet extends ConsumerStatefulWidget {
  const PurchaseDetailSheet({super.key, required this.initialPurchaseId});

  final String initialPurchaseId;

  @override
  ConsumerState<PurchaseDetailSheet> createState() =>
      _PurchaseDetailSheetState();
}

class _PurchaseDetailSheetState extends ConsumerState<PurchaseDetailSheet> {
  late String _purchaseId = widget.initialPurchaseId;
  bool _busy = false;

  Future<void> _run(Future<String?> Function(HouseholdActions a) op) async {
    final actions = ref.read(householdActionsProvider);
    if (actions == null || _busy) return;
    setState(() => _busy = true);
    try {
      final newId = await op(actions);
      if (newId != null && mounted) setState(() => _purchaseId = newId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(householdStateProvider).value;
    final purchase = state?.purchases[_purchaseId];

    if (purchase == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text('This purchase is no longer available.'),
      );
    }

    final sliceName = _sliceName(state!, purchase.target);
    final inheritedTaxDefault = _inheritedTaxDefault(state, purchase.target);
    final canShare = purchase.target is SliceCharge
        ? !(state.slices[(purchase.target as SliceCharge).sliceId]?.isGroup ??
            false)
        : purchase.target is VaultCharge;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatMoney(purchase.amountCents),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration:
                              purchase.voided ? TextDecoration.lineThrough : null,
                        ),
                  ),
                ),
                if (purchase.voided)
                  const Chip(label: Text('Voided'))
                else
                  TextButton.icon(
                    onPressed: _busy ? null : () => _confirmVoid(purchase),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Void'),
                  ),
              ],
            ),
            Text(
              sliceName,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            _fieldTile(
              icon: Icons.storefront_outlined,
              label: 'Merchant',
              value: purchase.merchant ?? 'Add merchant',
              set: purchase.merchant != null,
              onTap: () => _editText(
                title: 'Merchant',
                initial: purchase.merchant,
                onSave: (v) => _run((a) => a.amendPurchase(purchase, merchant: v)),
              ),
            ),
            _fieldTile(
              icon: Icons.notes_outlined,
              label: 'Note',
              value: purchase.note ?? 'Add note',
              set: purchase.note != null,
              onTap: () => _editText(
                title: 'Note',
                initial: purchase.note,
                onSave: (v) => _run((a) => a.amendPurchase(purchase, note: v)),
              ),
            ),
            _fieldTile(
              icon: Icons.event_outlined,
              label: 'Date',
              value: _dateLabel(purchase.occurredAt),
              set: true,
              onTap: () => _pickDate(purchase),
            ),
            if (canShare)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.people_alt_outlined),
                title: const Text('Split 50/50'),
                value: purchase.shared,
                onChanged: _busy
                    ? null
                    : (v) => _run((a) => a.amendPurchase(purchase, shared: v)),
              ),
            _taxTile(purchase, inheritedTaxDefault),
            const Divider(),
            _receiptsSection(purchase),
          ],
        ),
      ),
    );
  }

  Widget _taxTile(PurchaseState purchase, bool inheritedDefault) {
    final effective = purchase.taxDeductible ?? inheritedDefault;
    final overridden = purchase.taxDeductible != null;
    // Tax stays unobtrusive: in the adventure skin a deductible purchase carries
    // a small scroll-seal here on the detail sheet and nowhere else.
    final adventure = ref.watch(appSkinProvider) == AppSkin.adventure;
    final scheme = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: const Icon(Icons.receipt_long_outlined),
      title: Row(
        children: [
          const Text('Tax deductible'),
          if (adventure && effective)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: Tooltip(
                message: 'Scroll seal — counts toward the tax package',
                child: Icon(Icons.approval, size: 18, color: scheme.tertiary),
              ),
            ),
        ],
      ),
      subtitle: Text(
        overridden
            ? 'Overriding default (${inheritedDefault ? 'yes' : 'no'})'
            : 'Inherits category default (${inheritedDefault ? 'yes' : 'no'})',
      ),
      value: effective,
      onChanged: _busy
          ? null
          : (v) => _run((a) => a.amendPurchase(
                purchase,
                taxDeductible: v == inheritedDefault ? null : v,
              )),
    );
  }

  Widget _receiptsSection(PurchaseState purchase) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Receipts', style: AppText.sectionLabel(context)),
            ),
            TextButton.icon(
              onPressed: _busy ? null : () => _attachReceipts(purchase),
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Attach'),
            ),
          ],
        ),
        if (purchase.receipts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              'No receipts attached',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          )
        else
          Column(
            children: [
              for (final r in purchase.receipts)
                _receiptTile(purchase.purchaseId, r),
            ],
          ),
      ],
    );
  }

  Widget _receiptTile(String purchaseId, ReceiptRef r) {
    final isPdf = r.mimeType == 'application/pdf';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
      title: Text(isPdf ? 'PDF receipt' : 'Image receipt'),
      subtitle: Text('${(r.sizeBytes / 1024).toStringAsFixed(0)} KB'),
      onTap: isPdf ? null : () => _viewImage(r.sha256),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Detach',
        onPressed: _busy
            ? null
            : () => _run((a) async {
                  await a.detachReceipt(purchaseId, r.sha256);
                  return null;
                }),
      ),
    );
  }

  Future<void> _viewImage(String sha256) async {
    final store = ref.read(blobStoreProvider);
    // An offloaded receipt lives on the hubs; fetch it back on demand.
    if (!await store.exists(sha256)) {
      final fetched =
          await ref.read(syncServiceProvider)?.fetchBlob(sha256) ?? false;
      if (!fetched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('This receipt lives on your hub. Connect to your '
                'home network to view it.'),
          ));
        }
        return;
      }
    }
    final bytes = await store.read(sha256);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.memory(bytes)),
      ),
    );
  }

  Future<void> _confirmVoid(PurchaseState purchase) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Void this purchase?'),
        content: const Text(
          'It stays in the ledger for audit but no longer counts against any '
          'budget.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Void'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await _run((a) async {
        await a.voidPurchase(purchase.purchaseId);
        return null;
      });
    }
  }

  Future<void> _editText({
    required String title,
    required String? initial,
    required ValueChanged<String?> onSave,
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      final trimmed = result.trim();
      onSave(trimmed.isEmpty ? null : trimmed);
    }
  }

  Future<void> _pickDate(PurchaseState purchase) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: purchase.occurredAt.isAfter(now) ? now : purchase.occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) {
      final at = DateTime(
        picked.year,
        picked.month,
        picked.day,
        purchase.occurredAt.hour,
        purchase.occurredAt.minute,
      );
      await _run((a) => a.amendPurchase(purchase, occurredAt: at));
    }
  }

  Future<void> _attachReceipts(PurchaseState purchase) async {
    final picks = await _pickReceiptFiles();
    if (picks.isEmpty) return;
    await _run((a) async {
      for (final f in picks) {
        await a.attachReceiptBytes(purchase.purchaseId, f.bytes, isPdf: f.isPdf);
      }
      return null;
    });
    await _maybeSuggestScannedTotal(purchase, picks);
  }

  /// Flow (b): after attaching a receipt to an existing purchase, offer a
  /// non-blocking "use scanned total?" suggestion — but only when OCR is
  /// available and the scanned total actually differs from the recorded amount.
  Future<void> _maybeSuggestScannedTotal(
    PurchaseState purchase,
    List<_PickedFile> picks,
  ) async {
    final ocr = ref.read(receiptOcrProvider);
    if (!ocr.isSupported) return;
    final image = picks.firstWhere(
      (f) => !f.isPdf && f.path != null,
      orElse: () => _PickedFile(bytes: _empty, isPdf: true),
    );
    if (image.path == null) return;

    try {
      final scan = await ocr.scanImageFile(image.path!);
      final total = scan.bestTotalCents;
      if (total == null || total == purchase.amountCents || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Receipt scanned ${formatMoney(total)}'),
          action: SnackBarAction(
            label: 'Use total',
            onPressed: () =>
                _run((a) => a.amendPurchase(purchase, amountCents: total)),
          ),
        ),
      );
    } on Object {
      // A failed scan is silent — the receipt is already attached.
    }
  }

  /// Picks receipt files: camera/gallery on mobile, a file dialog on desktop.
  Future<List<_PickedFile>> _pickReceiptFiles() async {
    final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (isMobile) {
      final images = await ImagePicker().pickMultiImage();
      return [
        for (final x in images)
          _PickedFile(
            bytes: await x.readAsBytes(),
            isPdf: _looksPdf(x),
            path: x.path,
          ),
      ];
    }
    const group = XTypeGroup(
      label: 'Receipts',
      extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );
    final files = await openFiles(acceptedTypeGroups: [group]);
    return [
      for (final x in files)
        _PickedFile(
          bytes: await x.readAsBytes(),
          isPdf: _looksPdf(x),
          path: x.path,
        ),
    ];
  }

  static bool _looksPdf(XFile x) =>
      (x.mimeType?.contains('pdf') ?? false) ||
      x.name.toLowerCase().endsWith('.pdf');

  String _dateLabel(DateTime at) =>
      '${at.year}-${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  String _sliceName(HouseholdState state, ChargeTarget target) {
    switch (target) {
      case SliceCharge(:final sliceId):
        return state.slices[sliceId]?.name ?? 'Budget';
      case VaultCharge():
        return 'Vault';
      case QuestCharge(:final questId):
        return state.quests[questId]?.name ?? 'Quest';
      case EmergencyCharge(:final fundId):
        return state.emergencyFunds[fundId]?.name ?? 'Emergency fund';
      case VacationCharge(:final vacationId):
        return state.vacations[vacationId]?.name ?? 'Vacation';
    }
  }

  bool _inheritedTaxDefault(HouseholdState state, ChargeTarget target) {
    if (target is SliceCharge) {
      return state.slices[target.sliceId]?.taxDeductibleByDefault ?? false;
    }
    return false;
  }

  Widget _fieldTile({
    required IconData icon,
    required String label,
    required String value,
    required bool set,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
      trailing: const Icon(Icons.chevron_right),
      onTap: _busy ? null : onTap,
    );
  }
}

class _PickedFile {
  const _PickedFile({required this.bytes, required this.isPdf, this.path});
  final Uint8List bytes;
  final bool isPdf;
  final String? path;
}

final Uint8List _empty = Uint8List(0);
