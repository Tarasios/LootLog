/// The OCR confirm screen (pure view).
///
/// Confirm-only OCR: a scan may *prefill* the amount, date, and merchant and the
/// receipt is shown pre-attached, but nothing is created until the user presses
/// Confirm. The amount is the focused, editable field and must be > 0; a charge
/// target must be chosen. The screen wrapper turns [OcrConfirmResult] into an
/// appended purchase and attaches the receipt blob.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ocr/receipt_parse.dart';
import '../../ui/theme.dart';
import '../entry/amount_keypad.dart';
import '../entry/charge_choice.dart';

/// The confirmed, user-approved purchase fields from the OCR flow.
class OcrConfirmResult {
  const OcrConfirmResult({
    required this.choice,
    required this.amountCents,
    required this.occurredAt,
    this.merchant,
  });

  final ChargeChoice choice;
  final int amountCents;
  final DateTime occurredAt;
  final String? merchant;
}

class OcrConfirmView extends StatefulWidget {
  const OcrConfirmView({
    super.key,
    required this.groups,
    required this.scan,
    required this.onConfirm,
    this.receiptThumbnail,
    this.onClose,
    this.now,
  });

  final List<ChargeGroup> groups;
  final ReceiptScan scan;
  final ValueChanged<OcrConfirmResult> onConfirm;

  /// Optional thumbnail of the pre-attached receipt; a placeholder card is shown
  /// when null (keeps golden tests free of async image decoding).
  final Widget? receiptThumbnail;
  final VoidCallback? onClose;
  final DateTime? now;

  @override
  State<OcrConfirmView> createState() => _OcrConfirmViewState();
}

class _OcrConfirmViewState extends State<OcrConfirmView> {
  late int _cents = widget.scan.bestTotalCents ?? 0;
  late final TextEditingController _merchant =
      TextEditingController(text: widget.scan.merchantGuess ?? '');
  late DateTime _occurredAt = widget.scan.candidateDate ?? _today;
  ChargeChoice? _selected;

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _canConfirm => _cents > 0 && _selected != null;

  @override
  void dispose() {
    _merchant.dispose();
    super.dispose();
  }

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = event.logicalKey;
    final digit = digitForKey(k);
    if (digit != null) {
      setState(() => _cents = applyDigit(_cents, digit));
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.backspace) {
      setState(() => _cents = applyBackspace(_cents));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _pickDate() async {
    final now = widget.now ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt.isAfter(now) ? now : _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Receipt date',
    );
    if (picked != null) {
      setState(() => _occurredAt = DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _confirm() {
    if (!_canConfirm) return;
    final merchant = _merchant.text.trim();
    widget.onConfirm(OcrConfirmResult(
      choice: _selected!,
      amountCents: _cents,
      occurredAt: _occurredAt,
      merchant: merchant.isEmpty ? null : merchant,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-'
        '${_occurredAt.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose ?? () => Navigator.maybePop(context),
          tooltip: 'Discard scan',
        ),
        title: const Text('Confirm expense'),
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onHardwareKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  children: [
                    _scannedBanner(context),
                    const SizedBox(height: AppSpacing.sm),
                    AmountDisplay(cents: _cents),
                    const SizedBox(height: AppSpacing.sm),
                    AmountKeypad(
                      cents: _cents,
                      onChanged: (v) => setState(() => _cents = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _merchant,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Merchant',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.event_outlined),
                      title: const Text('Date'),
                      trailing: Text(dateLabel),
                      onTap: _pickDate,
                    ),
                    const Divider(),
                    Text('Charge to', style: AppText.sectionLabel(context)),
                    const SizedBox(height: AppSpacing.sm),
                    for (final group in widget.groups)
                      _groupSection(context, group),
                  ],
                ),
              ),
              _confirmBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scannedBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: widget.receiptThumbnail ??
                Icon(Icons.receipt_long_outlined, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Receipt attached',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  'Scanned — check the amount before saving',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupSection(BuildContext context, ChargeGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: Text(group.label, style: AppText.sectionLabel(context)),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final choice in group.choices)
                ChoiceChip(
                  label: Text(choice.label),
                  selected: _selected?.target == choice.target,
                  onSelected: (_) => setState(() => _selected = choice),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _confirmBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: FilledButton.icon(
        onPressed: _canConfirm ? _confirm : null,
        icon: const Icon(Icons.check),
        label: Text(
          _selected == null ? 'Pick where it goes' : 'Confirm expense',
        ),
      ),
    );
  }
}
