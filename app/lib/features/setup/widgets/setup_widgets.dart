part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Shared little widgets of the setup wizard
// ---------------------------------------------------------------------------

class _StepIntro extends StatelessWidget {
  const _StepIntro(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.card,
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSecondaryContainer, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// A money text field bound to a cents value, tolerant of `$`, commas, decimals.
class _MoneyField extends StatefulWidget {
  const _MoneyField({
    required this.label,
    required this.cents,
    required this.onChanged,
  });

  final String label;
  final int cents;
  final ValueChanged<int> onChanged;

  @override
  State<_MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<_MoneyField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.cents == 0 ? '' : Money(widget.cents).format());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,$ ]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        prefixText: '\$',
      ),
      onChanged: (value) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(0);
          return;
        }
        try {
          widget.onChanged(Money.parse(trimmed).cents);
        } on FormatException {
          // Ignore partial input; the last valid value stands.
        }
      },
    );
  }
}

class _OwnerDropdown extends StatelessWidget {
  const _OwnerDropdown({
    required this.adults,
    required this.value,
    required this.onChanged,
  });

  final List<DraftMember> adults;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Owner'),
      items: [
        for (final adult in adults)
          DropdownMenuItem(value: adult.localId, child: Text(adult.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _CadenceDropdown extends StatelessWidget {
  const _CadenceDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AccountCadence value;
  final ValueChanged<AccountCadence> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AccountCadence>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final cadence in AccountCadence.values)
          DropdownMenuItem(value: cadence, child: Text(cadence.name)),
      ],
      onChanged: (value) => value == null ? null : onChanged(value),
    );
  }
}

class _MonthDropdown extends StatelessWidget {
  const _MonthDropdown({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Due month'),
      items: [
        for (var monthNumber = 1; monthNumber <= 12; monthNumber++)
          DropdownMenuItem(value: monthNumber, child: Text(monthLabel(2026, monthNumber).split(' ').first)),
      ],
      onChanged: (value) => value == null ? null : onChanged(value),
    );
  }
}

// ---- role helpers ---------------------------------------------------------

String _roleWord(DraftRole role) => switch (role) {
      DraftRole.adult => 'adult',
      DraftRole.dependent => 'dependent',
      DraftRole.pet => 'pet',
    };

String _rolePlural(DraftRole role) => switch (role) {
      DraftRole.adult => 'Adults',
      DraftRole.dependent => 'Dependents',
      DraftRole.pet => 'Pets',
    };

IconData _roleIcon(DraftRole role) => switch (role) {
      DraftRole.adult => Icons.person_outline,
      DraftRole.dependent => Icons.child_care_outlined,
      DraftRole.pet => Icons.pets_outlined,
    };

IconData _accountIcon(AccountKind kind) => switch (kind) {
      AccountKind.savings => Icons.savings_outlined,
      AccountKind.investment => Icons.show_chart,
      AccountKind.debt => Icons.credit_card,
      AccountKind.cash => Icons.attach_money,
    };
