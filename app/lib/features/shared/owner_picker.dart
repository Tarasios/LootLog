/// One owner picker for every editor that assigns something to an adult or to
/// the whole household: a chip per active adult plus a household chip. Works
/// for any party size — a single adult sees one chip, five adults see five.
library;

import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../household_roster.dart';

class OwnerPicker extends StatelessWidget {
  const OwnerPicker({
    super.key,
    required this.adults,
    required this.selectedUserId,
    required this.onChanged,
    this.householdLabel = 'Group',
  });

  /// The selectable adults, in display order.
  final List<RosterEntry> adults;

  /// The selected adult's id, or null when the household owns it.
  final String? selectedUserId;

  final ValueChanged<String?> onChanged;

  /// Label for the household-owned choice ("Group", "Shared").
  final String householdLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final a in adults)
          ChoiceChip(
            label: Text(a.name),
            selected: selectedUserId == a.id,
            onSelected: (_) => onChanged(a.id),
          ),
        ChoiceChip(
          avatar: const Icon(Icons.groups_outlined, size: 18),
          label: Text(householdLabel),
          selected: selectedUserId == null,
          onSelected: (_) => onChanged(null),
        ),
      ],
    );
  }
}
