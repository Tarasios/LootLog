/// A compact month picker: two dropdowns (month, year) rendered as a labelled
/// field. Used wherever a household [Month] must be chosen (recurring expenses,
/// account balances). Optional clearing supports "no end month".
library;

import 'package:flutter/material.dart';

import '../../domain/time.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';

class MonthField extends StatelessWidget {
  const MonthField({
    super.key,
    required this.label,
    required this.month,
    required this.onChanged,
    this.onClear,
  });

  final String label;

  /// The selected month, or null when unset (only meaningful if [onClear] set).
  final Month? month;
  final void Function(Month) onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    final years = [for (var y = nowYear - 3; y <= nowYear + 3; y++) y];
    final m = month ?? Month.fromInstant(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(labelText: label),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: m.month,
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(monthLabel(m.year, i).split(' ').first),
                          ),
                      ],
                      onChanged: (v) =>
                          v == null ? null : onChanged(Month(m.year, v)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: years.contains(m.year) ? m.year : null,
                      items: [
                        for (final y in years)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) =>
                          v == null ? null : onChanged(Month(v, m.month)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onClear != null && month != null)
          IconButton(
            tooltip: 'Clear',
            onPressed: onClear,
            icon: const Icon(Icons.clear),
          ),
      ],
    );
  }
}
