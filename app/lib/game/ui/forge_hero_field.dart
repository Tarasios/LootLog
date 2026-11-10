/// One free cosmetic field of the hero editor on the Forge screen (name,
/// title, motto): a text field and its Save button. Saving is free and goes
/// through the game's `customizeHero` command.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../config/balance.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'kit/kit.dart';

class ForgeHeroField extends ConsumerStatefulWidget {
  const ForgeHeroField({
    super.key,
    required this.field,
    required this.label,
    required this.initial,
  });

  final String field;
  final String label;
  final String initial;

  @override
  ConsumerState<ForgeHeroField> createState() => _ForgeHeroFieldState();
}

class _ForgeHeroFieldState extends ConsumerState<ForgeHeroField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = hallTextTier(context);
    final input = TextField(
      controller: _controller,
      maxLength: Balance.maxCosmeticValueLength,
      style: text ? null : const TextStyle(color: AdventureTokens.ink),
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        isDense: true,
        border: text ? null : InputBorder.none,
        labelStyle: text ? null : const TextStyle(color: AdventureTokens.inkMuted),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: text
                ? input
                : InsetWell(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: input,
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FramedButton(label: 'Save', secondary: true, onPressed: _save),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await runHallCommand(context, ref,
        (s) => s.customizeHero(field: widget.field, value: _controller.text.trim()));
    if (result != null && result.accepted) {
      messenger?.showSnackBar(SnackBar(content: Text('${widget.label} saved.')));
    }
  }
}
