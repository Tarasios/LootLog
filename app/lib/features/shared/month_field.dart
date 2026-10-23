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
    final years = [
      for (var year = nowYear - 3; year <= nowYear + 3; year++) year,
    ];
    final initial = month ?? Month.fromInstant(DateTime.now());
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
                      value: initial.month,
                      items: [
                        for (var i = 1; i <= 12; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              monthLabel(initial.year, i).split(' ').first,
                            ),
                          ),
                      ],
                      onChanged: (value) => value == null
                          ? null
                          : onChanged(Month(initial.year, value)),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: years.contains(initial.year) ? initial.year : null,
                      items: [
                        for (final year in years)
                          DropdownMenuItem(value: year, child: Text('$year')),
                      ],
                      onChanged: (value) => value == null
                          ? null
                          : onChanged(Month(value, initial.month)),
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
