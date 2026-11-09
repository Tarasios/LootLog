/// The grouped charge chips shared by quick entry and the Adventure
/// log-purchase dialog: a heading, the everyday groups, and the rarer vault
/// and goal groups behind a "More targets" button. Tapping a chip is the
/// commit, so the picker only reports which [ChargeChoice] was picked.
///
/// The picker does not scroll; its host decides how it sits on screen. Its
/// section labels and button read the ambient [Theme], and each chip is drawn
/// by a [ChargeChipBuilder] (by default a [ChargeChip]).
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import 'charge_choice.dart';

/// Draws one tappable charge destination that calls [onTap].
typedef ChargeChipBuilder = Widget Function(
  BuildContext context,
  ChargeChoice choice,
  VoidCallback onTap,
);

class ChargePicker extends StatefulWidget {
  const ChargePicker({
    super.key,
    required this.groups,
    required this.onPick,
    this.heading = 'Charge to',
    this.chipBuilder = _defaultChip,
  });

  final List<ChargeGroup> groups;
  final ValueChanged<ChargeChoice> onPick;
  final String heading;
  final ChargeChipBuilder chipBuilder;

  static Widget _defaultChip(
    BuildContext context,
    ChargeChoice choice,
    VoidCallback onTap,
  ) => ChargeChip(choice: choice, onTap: onTap);

  /// Everyday spending targets show immediately; the vault and quests are
  /// rarer, deliberate moves and stay behind "More targets" so the everyday
  /// picker reads as "which budget did this come from".
  static bool isAdvanced(ChargeGroup group) =>
      group.kind == ChargeGroupKind.vault ||
      group.kind == ChargeGroupKind.quest;

  @override
  State<ChargePicker> createState() => _ChargePickerState();
}

class _ChargePickerState extends State<ChargePicker> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final primary = [
      for (final group in widget.groups)
        if (!ChargePicker.isAdvanced(group)) group,
    ];
    final advanced = [
      for (final group in widget.groups)
        if (ChargePicker.isAdvanced(group)) group,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(widget.heading, style: AppText.sectionLabel(context)),
        ),
        for (final group in primary) _groupSection(context, group),
        if (advanced.isNotEmpty && !_showMore)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: TextButton.icon(
              onPressed: () => setState(() => _showMore = true),
              icon: const Icon(Icons.unfold_more),
              label: Text(
                'More targets '
                '(${advanced.map((group) => group.label.toLowerCase()).join(', ')})',
              ),
            ),
          ),
        if (_showMore)
          for (final group in advanced) _groupSection(context, group),
      ],
    );
  }

  Widget _groupSection(BuildContext context, ChargeGroup group) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(group.label, style: AppText.sectionLabel(context)),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final choice in group.choices)
                widget.chipBuilder(
                  context,
                  choice,
                  () => widget.onPick(choice),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One tappable charge destination, tinted by its kind so groups read as
/// distinct at a glance.
class ChargeChip extends StatelessWidget {
  const ChargeChip({super.key, required this.choice, required this.onTap});

  final ChargeChoice choice;
  final VoidCallback onTap;

  ({Color bg, Color fg}) _colors(ColorScheme scheme) {
    switch (choice.kind) {
      case ChargeGroupKind.personalSlice:
        return (bg: scheme.primaryContainer, fg: scheme.onPrimaryContainer);
      case ChargeGroupKind.groupSlice:
        return (bg: scheme.tertiaryContainer, fg: scheme.onTertiaryContainer);
      case ChargeGroupKind.vault:
        return (bg: scheme.secondaryContainer, fg: scheme.onSecondaryContainer);
      case ChargeGroupKind.quest:
        return (bg: scheme.surfaceContainerHighest, fg: scheme.onSurface);
      case ChargeGroupKind.emergency:
        return (bg: scheme.errorContainer, fg: scheme.onErrorContainer);
      case ChargeGroupKind.vacation:
        return (bg: scheme.tertiaryContainer, fg: scheme.onTertiaryContainer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = _colors(scheme);
    return Material(
      color: colors.bg,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 108, maxWidth: 200),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chargeKindIcon(choice.kind), size: 18, color: colors.fg),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        choice.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.fg,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (choice.subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      choice.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.fg.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The icon for a kind of charge destination.
IconData chargeKindIcon(ChargeGroupKind kind) {
  switch (kind) {
    case ChargeGroupKind.personalSlice:
      return Icons.account_balance_wallet_outlined;
    case ChargeGroupKind.groupSlice:
      return Icons.groups_outlined;
    case ChargeGroupKind.vault:
      return Icons.savings_outlined;
    case ChargeGroupKind.quest:
      return Icons.flag_outlined;
    case ChargeGroupKind.emergency:
      return Icons.emergency_outlined;
    case ChargeGroupKind.vacation:
      return Icons.beach_access_outlined;
  }
}
