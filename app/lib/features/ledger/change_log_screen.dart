/// The **budget change log**: the audit view over the whole event log. Every
/// change the household ever made is here, newest first, in plain language —
/// because event sourcing is the audit trail and nothing is ever deleted.
/// Corrections (a void, a compensating entry) appear as their own lines.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import 'change_log_model.dart';

class ChangeLogScreen extends ConsumerWidget {
  const ChangeLogScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ChangeLogScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final eventsAsync = ref.watch(eventLogProvider);
    final names = ref.watch(userNamesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budget change log')),
      body: eventsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the log.\n$e')),
        data: (events) {
          if (state == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = buildChangeLog(state, events, userNames: names);
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: entries.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) return const _LogHeader();
              return _ChangeLogTile(entry: entries[i - 1]);
            },
          );
        },
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.lock_clock, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Every change is permanently logged and can never be deleted. '
              'Corrections are recorded as new entries, keeping the original.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeLogTile extends StatelessWidget {
  const _ChangeLogTile({required this.entry});

  final ChangeLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amount = entry.amountCents;
    return ListTile(
      leading: Icon(_iconFor(entry.kind), color: scheme.onSurfaceVariant),
      title: Text(entry.title),
      subtitle: Text(
        [
          entry.author,
          isoDay(entry.occurredAt),
          if (entry.detail != null) entry.detail,
        ].join(' · '),
      ),
      trailing: amount == null
          ? null
          : Text(
              signedMoney(amount),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: amount < 0 ? scheme.error : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
      isThreeLine: entry.detail != null && entry.detail!.length > 24,
    );
  }

  static IconData _iconFor(ChangeLogKind kind) => switch (kind) {
        ChangeLogKind.purchase => Icons.shopping_bag_outlined,
        ChangeLogKind.correction => Icons.undo,
        ChangeLogKind.money => Icons.payments_outlined,
        ChangeLogKind.config => Icons.tune,
        ChangeLogKind.governance => Icons.gavel_outlined,
        ChangeLogKind.receipt => Icons.receipt_outlined,
        ChangeLogKind.cosmetic => Icons.palette_outlined,
      };
}
