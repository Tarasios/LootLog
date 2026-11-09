/// The full-screen quick-entry view: a big cents-aware amount, a keypad, a row
/// of optional inline fields, and grouped charge chips. Tapping a charge chip is
/// the commit — three interactions from FAB to saved.
///
/// This widget is deliberately pure: it takes its [groups] and hands back an
/// [EntryDraft] via [onCommit]. The screen wrapper turns that into an appended
/// event. That keeps it trivially golden-testable at phone size.
library;

import 'package:flutter/material.dart';

import '../../domain/money.dart';
import '../../ui/theme.dart';
import 'amount_keypad.dart';
import 'charge_choice.dart';
import 'charge_picker.dart';

/// Everything the screen needs to record a purchase, gathered by the view.
class EntryDraft {
  const EntryDraft({
    required this.choice,
    required this.amountCents,
    required this.shared,
    required this.occurredAt,
    this.merchant,
    this.note,
  });

  final ChargeChoice choice;
  final int amountCents;
  final bool shared;
  final DateTime occurredAt;
  final String? merchant;
  final String? note;
}

class ExpenseEntryView extends StatefulWidget {
  const ExpenseEntryView({
    super.key,
    required this.groups,
    required this.onCommit,
    this.onClose,
    this.initialCents = 0,
    this.now,
  });

  final List<ChargeGroup> groups;
  final ValueChanged<EntryDraft> onCommit;
  final VoidCallback? onClose;
  final int initialCents;

  /// Injectable clock so the default date and golden tests are deterministic.
  final DateTime? now;

  @override
  State<ExpenseEntryView> createState() => _ExpenseEntryViewState();
}

class _ExpenseEntryViewState extends State<ExpenseEntryView> {
  late int _cents = widget.initialCents;
  bool _shared = false;
  String? _merchant;
  String? _note;
  late DateTime _occurredAt = widget.now ?? DateTime.now();

  bool get _sharedRelevant => widget.groups.any(
    (group) => group.choices.any((choice) => choice.supportsShared),
  );

  bool get _isToday {
    final now = widget.now ?? DateTime.now();
    return _occurredAt.year == now.year &&
        _occurredAt.month == now.month &&
        _occurredAt.day == now.day;
  }

  void _onKey(int cents) => setState(() => _cents = cents);

  KeyEventResult _onHardwareKey(FocusNode node, KeyEvent event) {
    final next = amountAfterKeyEvent(event, _cents);
    if (next == null) return KeyEventResult.ignored;
    setState(() => _cents = next);
    return KeyEventResult.handled;
  }

  void _commit(ChargeChoice choice) {
    if (_cents <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an amount first')));
      return;
    }
    widget.onCommit(
      EntryDraft(
        choice: choice,
        amountCents: _cents,
        shared: _shared && choice.supportsShared,
        occurredAt: _occurredAt,
        merchant: _merchant,
        note: _note,
      ),
    );
  }

  Future<void> _editText({
    required String title,
    required String? initial,
    required ValueChanged<String?> onSaved,
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
          onSubmitted: (value) => Navigator.pop(context, value),
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
      onSaved(trimmed.isEmpty ? null : trimmed);
    }
  }

  Future<void> _pickDate() async {
    final now = widget.now ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Backdate this expense',
    );
    if (picked != null) {
      setState(
        () => _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          now.hour,
          now.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: widget.onClose ?? () => Navigator.maybePop(context),
          tooltip: 'Cancel',
        ),
        title: const Text('New expense'),
      ),
      body: SafeArea(
        child: Focus(
          autofocus: true,
          onKeyEvent: _onHardwareKey,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.sm,
                ),
                child: AmountDisplay(cents: _cents),
              ),
              _optionsRow(context),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: AmountKeypad(cents: _cents, onChanged: _onKey),
              ),
              const Divider(),
              Expanded(child: _chargeArea(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionsRow(BuildContext context) {
    final dateLabel = _isToday
        ? 'Today'
        : '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-'
              '${_occurredAt.day.toString().padLeft(2, '0')}';
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          if (_sharedRelevant)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: FilterChip(
                label: const Text('Shared'),
                tooltip:
                    'Split with the other adults by the household share table',
                avatar: const Icon(Icons.people_alt_outlined, size: 18),
                selected: _shared,
                onSelected: (value) => setState(() => _shared = value),
              ),
            ),
          _optionChip(
            icon: Icons.storefront_outlined,
            label: _merchant ?? 'Merchant',
            active: _merchant != null,
            onTap: () => _editText(
              title: 'Merchant',
              initial: _merchant,
              onSaved: (value) => setState(() => _merchant = value),
            ),
          ),
          _optionChip(
            icon: Icons.notes_outlined,
            label: _note == null ? 'Note' : 'Note ✓',
            active: _note != null,
            onTap: () => _editText(
              title: 'Note',
              initial: _note,
              onSaved: (value) => setState(() => _note = value),
            ),
          ),
          _optionChip(
            icon: Icons.event_outlined,
            label: dateLabel,
            active: !_isToday,
            onTap: _pickDate,
          ),
        ],
      ),
    );
  }

  Widget _optionChip({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: ActionChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onPressed: onTap,
        side: active
            ? BorderSide(color: Theme.of(context).colorScheme.primary)
            : null,
      ),
    );
  }

  Widget _chargeArea(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: ChargePicker(groups: widget.groups, onPick: _commit),
    );
  }
}

/// Formats cents for display; small helper kept next to the view that needs it.
String formatMoney(int cents) => '\$${Money(cents).format()}';
