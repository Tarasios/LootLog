/// The tax center (a quiet settings subpage): pick a calendar year to see the
/// deductible total and the itemized purchases (with a receipt indicator), then
/// export a tax package zip — summary.csv plus every referenced receipt.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/tax_package.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../household_context.dart';

class TaxCenterScreen extends ConsumerStatefulWidget {
  const TaxCenterScreen({super.key});

  @override
  ConsumerState<TaxCenterScreen> createState() => _TaxCenterScreenState();
}

class _TaxCenterScreenState extends ConsumerState<TaxCenterScreen> {
  int? _year;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final years = state.deductibleByYear.keys.toList()..sort();
    final currentYear = DateTime.now().year;
    if (!years.contains(currentYear)) years.add(currentYear);
    years.sort();
    final year = _year ?? (years.isNotEmpty ? years.last : currentYear);

    final deductibles = <DeductiblePurchase>[
      ...?state.deductibleByYear[year],
    ]..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final total = deductibles.fold<int>(0, (a, d) => a + d.amountCents);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax center')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Text('Tax year', style: AppText.sectionLabel(context)),
              const SizedBox(width: AppSpacing.md),
              DropdownButton<int>(
                value: year,
                items: [
                  for (final y in years)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) => setState(() => _year = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deductible total',
                      style: AppText.sectionLabel(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(money(total),
                      style: Theme.of(context).textTheme.headlineMedium),
                  Text('${deductibles.length} purchases',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed:
                _exporting || deductibles.isEmpty ? null : () => _export(year),
            icon: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.archive_outlined),
            label: Text(_exporting ? 'Exporting…' : 'Export tax package'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Deductible purchases', style: AppText.sectionLabel(context)),
          if (deductibles.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('No deductible purchases in this year.'),
            ),
          for (final d in deductibles)
            _DeductibleRow(d: d, userName: names[d.userId] ?? d.userId),
        ],
      ),
    );
  }

  Future<void> _export(int year) async {
    final messenger = ScaffoldMessenger.of(context);
    final state = ref.read(householdStateProvider).value;
    final names = ref.read(userNamesProvider);
    final blobs = ref.read(blobStoreProvider);
    if (state == null) return;

    setState(() => _exporting = true);
    try {
      final bytes = await writeTaxPackageZip(
        state,
        year: year,
        userNames: names,
        blobs: blobs,
      );
      final location = await getSaveLocation(
        suggestedName: 'tax-package-$year.zip',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Zip archive', extensions: ['zip']),
        ],
      );
      if (location == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
        return;
      }
      await File(location.path).writeAsBytes(bytes, flush: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to ${location.path}')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _DeductibleRow extends StatelessWidget {
  const _DeductibleRow({required this.d, required this.userName});

  final DeductiblePurchase d;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final hasReceipt = d.receiptShas.isNotEmpty;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        hasReceipt ? Icons.attachment : Icons.receipt_long_outlined,
        color: hasReceipt
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(d.merchant ?? d.sliceName),
      subtitle: Text(
        '${isoDay(d.occurredAt)} · $userName · ${d.sliceName}'
        '${d.shared ? ' · shared' : ''}',
      ),
      trailing: Text(money(d.amountCents),
          style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
