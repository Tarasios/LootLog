/// The cents-aware amount readout and keypad shared by quick entry, the OCR
/// confirm screen and the Adventure log-purchase dialog (which draws its keys
/// through an [AmountKeyBuilder]).
///
/// Entry is calculator-style: each digit shifts the running total left by one
/// place (a tap of `7` then `5` reads `$0.75`), backspace divides by ten. The
/// value is always integer cents — money never touches a `double`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/money.dart';
import '../../ui/theme.dart';

/// Largest enterable amount: $999,999.99. Keeps a stray key-repeat from
/// overflowing the display.
const int kMaxEntryCents = 99999999;

final Map<LogicalKeyboardKey, int> _hardwareDigits = {
  LogicalKeyboardKey.digit0: 0,
  LogicalKeyboardKey.numpad0: 0,
  LogicalKeyboardKey.digit1: 1,
  LogicalKeyboardKey.numpad1: 1,
  LogicalKeyboardKey.digit2: 2,
  LogicalKeyboardKey.numpad2: 2,
  LogicalKeyboardKey.digit3: 3,
  LogicalKeyboardKey.numpad3: 3,
  LogicalKeyboardKey.digit4: 4,
  LogicalKeyboardKey.numpad4: 4,
  LogicalKeyboardKey.digit5: 5,
  LogicalKeyboardKey.numpad5: 5,
  LogicalKeyboardKey.digit6: 6,
  LogicalKeyboardKey.numpad6: 6,
  LogicalKeyboardKey.digit7: 7,
  LogicalKeyboardKey.numpad7: 7,
  LogicalKeyboardKey.digit8: 8,
  LogicalKeyboardKey.numpad8: 8,
  LogicalKeyboardKey.digit9: 9,
  LogicalKeyboardKey.numpad9: 9,
};

/// The digit (0–9) for a physical/number-row key, or null. Lets desktop users
/// type an amount straight into the keypad.
int? digitForKey(LogicalKeyboardKey key) => _hardwareDigits[key];

/// Applies a single digit (0–9) to a running cents total, calculator-style.
int applyDigit(int cents, int digit) {
  final next = cents * 10 + digit;
  return next > kMaxEntryCents ? cents : next;
}

/// Removes the least-significant digit.
int applyBackspace(int cents) => cents ~/ 10;

/// The running total after a hardware [event] — a typed digit or Backspace —
/// or null when the event is not an amount key (or is a key release), so the
/// caller can leave it to other handlers.
int? amountAfterKeyEvent(KeyEvent event, int cents) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) return null;
  final digit = digitForKey(event.logicalKey);
  if (digit != null) return applyDigit(cents, digit);
  if (event.logicalKey == LogicalKeyboardKey.backspace) {
    return applyBackspace(cents);
  }
  return null;
}

/// The label of the keypad's backspace key; a custom [AmountKeyBuilder] may
/// draw it as an icon instead.
const String kBackspaceKeyLabel = '⌫';

/// Draws one keypad key showing [label] that calls [onTap]. [semanticsLabel]
/// is set when the label is a symbol (the backspace key). The keypad places
/// each key in an equal-width slot with a small gap around it.
typedef AmountKeyBuilder = Widget Function(
  BuildContext context,
  String label,
  String? semanticsLabel,
  VoidCallback onTap,
);

/// The big `$0.00` readout.
class AmountDisplay extends StatelessWidget {
  const AmountDisplay({super.key, required this.cents, this.enraged = false});

  final int cents;
  final bool enraged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '\$${Money(cents).format()}',
        maxLines: 1,
        style: AppText.amount(context).copyWith(
          color: cents == 0 ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
    );
  }
}

/// A 3×4 numeric keypad that edits a cents value. Each key is drawn by
/// [keyBuilder]: by default a rounded Material key in the theme's colours.
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.cents,
    required this.onChanged,
    this.keyBuilder = _materialKey,
  });

  final int cents;
  final ValueChanged<int> onChanged;
  final AmountKeyBuilder keyBuilder;

  static Widget _materialKey(
    BuildContext context,
    String label,
    String? semanticsLabel,
    VoidCallback onTap,
  ) => _KeypadButton(label: label, onTap: onTap, semanticsLabel: semanticsLabel);

  @override
  Widget build(BuildContext context) {
    Widget key(String label, VoidCallback onTap, {String? semantics}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: keyBuilder(context, label, semantics, onTap),
          ),
        );

    Widget digit(int digitValue) =>
        key('$digitValue', () => onChanged(applyDigit(cents, digitValue)));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [digit(1), digit(2), digit(3)]),
        Row(children: [digit(4), digit(5), digit(6)]),
        Row(children: [digit(7), digit(8), digit(9)]),
        Row(
          children: [
            key('00', () => onChanged(applyDigit(applyDigit(cents, 0), 0))),
            digit(0),
            key(
              kBackspaceKeyLabel,
              () => onChanged(applyBackspace(cents)),
              semantics: 'Backspace',
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.onTap,
    this.semanticsLabel,
  });

  final String label;
  final VoidCallback onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Center(
            child: Text(
              label,
              semanticsLabel: semanticsLabel,
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
      ),
    );
  }
}
