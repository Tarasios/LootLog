/// The Adventure log-purchase dialog's face: quick entry drawn in the game
/// kit. The amount sits in an inset well, the keypad keys are parchment
/// [WoodButton]s, and the destinations are parchment chips swatched in their
/// main category's colour. It is the Standard quick entry's flow exactly —
/// type the amount, tap where it came from, and that tap logs it — through the
/// same [AmountKeypad], [ChargePicker] and [EntryDraft]; only the drawing
/// differs.
///
/// Pure presentation: it takes its [ChargeGroup]s and hands back a draft via
/// `onCommit`; [LogPurchaseDialog] wires it to the ledger.
///
/// Keyboard: digits and Backspace edit the amount; Escape closes (the dialog
/// route's own dismiss); Enter moves to the first destination, and Enter on a
/// focused destination (or key) presses it.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/money.dart';
import '../../../features/entry/amount_keypad.dart';
import '../../../features/entry/charge_choice.dart';
import '../../../features/entry/charge_picker.dart';
import '../../../features/entry/expense_entry_view.dart' show EntryDraft;
import '../kit/kit.dart';
import 'log_purchase_chip.dart';

/// Wide enough to set the keypad beside the destinations.
const double _kSideBySideWidth = 600;

/// The keypad's width when it sits beside the destinations.
const double _kKeypadWidth = 280;

/// Narrower than this, destination chips go one to a row.
const double _kMinChipWidth = 140;

/// The nudge when a destination is tapped before any amount.
const String _kAskForAmount = 'Type the amount first';

/// The nudge when the purchase could not be written.
const String _kCommitFailed = 'Couldn’t log that — try again';

/// The amount readout's size: the app's default face, so any size is crisp.
const double _kAmountFontSize = 32;

class LogPurchaseView extends StatefulWidget {
  const LogPurchaseView({
    super.key,
    required this.groups,
    required this.onCommit,
    required this.onMoreDetails,
    required this.onClose,
    this.initialCents = 0,
    this.now,
  });

  final List<ChargeGroup> groups;

  /// Records the purchase; the dialog closes once it completes.
  final Future<void> Function(EntryDraft draft) onCommit;

  /// Opens the full entry screen, carrying the typed amount.
  final ValueChanged<int> onMoreDetails;
  final VoidCallback onClose;
  final int initialCents;

  /// Injectable clock for the purchase date.
  final DateTime? now;

  @override
  State<LogPurchaseView> createState() => _LogPurchaseViewState();
}

class _LogPurchaseViewState extends State<LogPurchaseView> {
  late int _cents = widget.initialCents;
  /// The nudge under the amount, or null.
  String? _notice;
  bool _committing = false;
  final FocusNode _rootFocus = FocusNode(debugLabel: 'log purchase');
  final FocusNode _destinationsFocus = FocusNode(
    debugLabel: 'log purchase destinations',
    skipTraversal: true,
  );

  @override
  void dispose() {
    _rootFocus.dispose();
    _destinationsFocus.dispose();
    super.dispose();
  }

  void _setAmount(int cents) => setState(() {
    _cents = cents;
    if (cents > 0 && _notice == _kAskForAmount) _notice = null;
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final next = amountAfterKeyEvent(event, _cents);
    if (next != null) {
      _setAmount(next);
      return KeyEventResult.handled;
    }
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    // Enter on a focused key or destination is that control's own press.
    if (event is! KeyDownEvent || !isEnter || !_rootFocus.hasPrimaryFocus) {
      return KeyEventResult.ignored;
    }
    if (_cents <= 0) {
      setState(() => _notice = _kAskForAmount);
    } else {
      _destinationsFocus.traversalDescendants.firstOrNull?.requestFocus();
    }
    return KeyEventResult.handled;
  }

  Future<void> _pick(ChargeChoice choice) async {
    if (_committing) return;
    if (_cents <= 0) {
      setState(() => _notice = _kAskForAmount);
      return;
    }
    // One purchase per dialog, however fast the taps come.
    setState(() {
      _committing = true;
      _notice = null;
    });
    try {
      await widget.onCommit(
        EntryDraft(
          choice: choice,
          amountCents: _cents,
          shared: false,
          occurredAt: widget.now ?? DateTime.now(),
        ),
      );
    } on Object {
      // The write failed: stay open with the amount kept, so a tap retries.
      if (mounted) {
        setState(() {
          _committing = false;
          _notice = _kCommitFailed;
        });
      }
      return;
    }
    // Close only this dialog, and only if nothing (Escape) closed it first.
    if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final keypad = AmountKeypad(
      cents: _cents,
      onChanged: _setAmount,
      keyBuilder: _woodKey,
    );
    return Focus(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: GameDialog(
        title: 'Log a purchase',
        maxWidth: 760,
        onClose: widget.onClose,
        actions: [
          WoodButton(
            label: 'More details',
            icon: Icons.edit_note,
            tone: WoodButtonTone.secondary,
            onPressed: _committing ? null : () => widget.onMoreDetails(_cents),
          ),
        ],
        body: LayoutBuilder(
          builder: (context, constraints) {
            final amount = _AmountWell(cents: _cents, notice: _notice);
            if (constraints.maxWidth < _kSideBySideWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  amount,
                  const SizedBox(height: AdventureTokens.gap),
                  keypad,
                  const SizedBox(height: AdventureTokens.gapLarge),
                  _destinations(constraints.maxWidth),
                ],
              );
            }
            final destinationsWidth =
                constraints.maxWidth - _kKeypadWidth - AdventureTokens.gapLarge;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _kKeypadWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      amount,
                      const SizedBox(height: AdventureTokens.gap),
                      keypad,
                    ],
                  ),
                ),
                const SizedBox(width: AdventureTokens.gapLarge),
                Expanded(child: _destinations(destinationsWidth)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// The destinations in [width]: two even columns of chips, or one when two
  /// would squeeze the names.
  Widget _destinations(double width) {
    final halfWidth = ((width - AdventureTokens.gap) / 2).floorToDouble();
    final chipWidth = halfWidth < _kMinChipWidth ? width : halfWidth;
    return Focus(
      focusNode: _destinationsFocus,
      child: ChargePicker(
        groups: widget.groups,
        heading: 'Tap where it came from to log it',
        onPick: _pick,
        chipBuilder: (context, choice, onTap) =>
            LogPurchaseChip(choice: choice, onTap: onTap, width: chipWidth),
      ),
    );
  }

  static Widget _woodKey(
    BuildContext context,
    String label,
    String? semanticsLabel,
    VoidCallback onTap,
  ) {
    final backspace = label == kBackspaceKeyLabel;
    return WoodButton(
      label: backspace ? '' : label,
      icon: backspace ? Icons.backspace_outlined : null,
      semanticsLabel: semanticsLabel,
      tone: WoodButtonTone.secondary,
      expand: true,
      large: true,
      onPressed: onTap,
    );
  }
}

/// The typed amount in an inset well, with a gentle [notice] under it (a
/// destination tapped before any amount, or a write that failed).
class _AmountWell extends StatelessWidget {
  const _AmountWell({required this.cents, required this.notice});

  final int cents;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final notice = this.notice;
    final style = AdventureTokens.amount(context).copyWith(
      fontSize: _kAmountFontSize,
      color: cents == 0 ? AdventureTokens.inkMuted : AdventureTokens.ink,
    );
    return InsetWell(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('\$${Money(cents).format()}', maxLines: 1, style: style),
          ),
          if (notice != null)
            Text(
              notice,
              textAlign: TextAlign.center,
              style: AdventureTokens.label(context).copyWith(color: AdventureTokens.ink),
            ),
        ],
      ),
    );
  }
}
