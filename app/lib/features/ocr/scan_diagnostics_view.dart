/// The read-out of one receipt scan, for the scanner test screen: verdict,
/// timing, any error, what the parser extracted ("not found" when absent),
/// and the raw recognized text. Pure presentation; it writes nothing.
library;

import 'package:flutter/material.dart';

import '../../data/ocr/receipt_scan_outcome.dart';
import '../../ui/theme.dart';
import '../entry/expense_entry_view.dart' show formatMoney;
import 'scan_issue_copy.dart';

/// Shown in place of an extracted value the parser could not find.
const notFoundLabel = 'not found';

class ScanDiagnosticsView extends StatelessWidget {
  const ScanDiagnosticsView({super.key, required this.outcome});

  final ReceiptScanOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final scan = outcome.scan;
    final bestTotal = scan.bestTotalCents;
    final date = scan.candidateDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(scanVerdict(outcome),
            style: Theme.of(context).textTheme.titleMedium),
        Text('Took ${outcome.elapsed.inMilliseconds} ms'),
        if (outcome.errorMessage != null) _errorCard(context),
        const SizedBox(height: AppSpacing.md),
        Text('What the scanner extracted', style: AppText.sectionLabel(context)),
        _field('Amount', bestTotal == null ? null : formatMoney(bestTotal)),
        _field('Date', date == null ? null : _isoDate(date)),
        _field('Merchant', scan.merchantGuess),
        if (scan.candidateTotals.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Other totals considered',
              style: AppText.sectionLabel(context)),
          for (final candidate in scan.candidateTotals.skip(1))
            Text('${formatMoney(candidate.amountCents)} — '
                '"${candidate.sourceLine}"'),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Raw recognized text', style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.xs),
        _rawText(context),
      ],
    );
  }

  Widget _errorCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
      ),
      child: SelectableText(
        'Error: ${outcome.errorMessage}',
        style: TextStyle(color: scheme.onErrorContainer),
      ),
    );
  }

  Widget _field(String label, String? value) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        trailing: Text(value ?? notFoundLabel),
      );

  Widget _rawText(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = outcome.recognizedText.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: SelectableText(
        text.isEmpty ? '(no text)' : outcome.recognizedText,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
  }

  static String _isoDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
