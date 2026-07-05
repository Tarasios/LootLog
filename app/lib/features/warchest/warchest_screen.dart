/// War-chest governance: balance and goal, pending writs (approve/decline on the
/// other member's device), the full ledger, and the actions that move pool money
/// — contribute from a vault (capped), propose a withdrawal, record a gift, and
/// record a tax refund.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import 'warchest_model.dart';

class WarChestScreen extends ConsumerWidget {
  const WarChestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    if (state == null || meUserId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ledger = buildWarChestLedger(state, events, userNames: names);
    final pending = state.withdrawals.values
        .where((w) => w.status == WithdrawalStatus.pending)
        .toList()
      ..sort((a, b) => a.purpose.compareTo(b.purpose));
    final chest = state.warChest;

    return Scaffold(
      appBar: AppBar(title: const Text('War chest')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('War chest',
                      style: AppText.sectionLabel(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(money(chest.balanceCents),
                      style: Theme.of(context).textTheme.headlineMedium),
                  if (chest.goal != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: chest.goal!.pctComplete.clamp(0.0, 1.0),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Goal ${money(chest.targetCents!)}'
                      '${chest.goal!.estMonthsRemaining != null ? ' · ~${chest.goal!.estMonthsRemaining!.ceil()} mo left' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _contribute(context, ref, state, meUserId),
                icon: const Icon(Icons.savings_outlined, size: 18),
                label: const Text('Contribute'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _propose(context, ref, state),
                icon: const Icon(Icons.request_quote_outlined, size: 18),
                label: const Text('Propose writ'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _recordGift(context, ref, state),
                icon: const Icon(Icons.card_giftcard, size: 18),
                label: const Text('Record gift'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _recordRefund(context, ref),
                icon: const Icon(Icons.request_page_outlined, size: 18),
                label: const Text('Tax refund'),
              ),
            ],
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Pending writs', style: AppText.sectionLabel(context)),
            for (final w in pending)
              _PendingWrit(writ: w, meUserId: meUserId, names: names),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Ledger', style: AppText.sectionLabel(context)),
          if (ledger.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('No pool activity yet.'),
            ),
          for (final e in ledger) _LedgerRow(entry: e),
        ],
      ),
    );
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref,
      HouseholdState state, String meUserId) async {
    final cap = state.vaultOf(meUserId);
    final cents = await _amountDialog(
      context,
      title: 'Contribute from your vault',
      helper: 'Capped at your vault: ${money(cap)}',
      max: cap,
    );
    if (cents != null && cents > 0) {
      await ref
          .read(householdActionsProvider)
          ?.contributeToPool(fromUserId: meUserId, amountCents: cents);
    }
  }

  Future<void> _propose(
      BuildContext context, WidgetRef ref, HouseholdState state) async {
    final result = await showModalBottomSheet<_WritDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _WritSheet(chestCents: state.warChest.balanceCents),
    );
    if (result != null) {
      await ref.read(householdActionsProvider)?.proposeWithdrawal(
            amountCents: result.amountCents,
            purpose: result.purpose,
            destination: result.destination,
          );
    }
  }

  Future<void> _recordGift(
      BuildContext context, WidgetRef ref, HouseholdState state) async {
    final setup = ref.read(localSetupProvider).value;
    if (setup == null) return;
    final names = ref.read(userNamesProvider);
    String recipient = setup.me.userId;
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: StatefulBuilder(
          builder: (context, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Record a gift',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.lg),
              DropdownButtonFormField<String>(
                initialValue: recipient,
                decoration: const InputDecoration(labelText: 'Recipient'),
                items: [
                  for (final p in setup.profiles)
                    DropdownMenuItem(
                        value: p.userId, child: Text(names[p.userId] ?? p.name)),
                ],
                onChanged: (v) => setSheet(() => recipient = v ?? recipient),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Amount', prefixText: r'$'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Record gift'),
              ),
            ],
          ),
        ),
      ),
    );

    if (ok == true) {
      final cents = tryParseMoneyCents(amountController.text);
      if (cents != null && cents > 0) {
        await ref.read(householdActionsProvider)?.recordGift(
              forUserId: recipient,
              amountCents: cents,
              note: noteController.text.trim().isEmpty
                  ? null
                  : noteController.text.trim(),
            );
      }
    }
  }

  Future<void> _recordRefund(BuildContext context, WidgetRef ref) async {
    final noteController = TextEditingController();
    final amountController = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record a tax refund',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Amount', prefixText: r'$'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Add to war chest'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final cents = tryParseMoneyCents(amountController.text);
      if (cents != null && cents > 0) {
        await ref.read(householdActionsProvider)?.recordTaxRefund(
              amountCents: cents,
              note: noteController.text.trim().isEmpty
                  ? null
                  : noteController.text.trim(),
            );
      }
    }
  }

  Future<int?> _amountDialog(
    BuildContext context, {
    required String title,
    String? helper,
    int? max,
  }) async {
    final controller = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(prefixText: r'$', helperText: helper),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final cents = tryParseMoneyCents(controller.text);
              if (cents == null || cents <= 0) return;
              if (max != null && cents > max) return;
              Navigator.of(context).pop(cents);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _PendingWrit extends ConsumerWidget {
  const _PendingWrit({
    required this.writ,
    required this.meUserId,
    required this.names,
  });

  final WithdrawalProposal writ;
  final String meUserId;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = writ.byUserId == meUserId;
    final dest = switch (writ.destination) {
      UserVaultDestination(:final userId) =>
        'to ${names[userId] ?? userId}\'s vault',
      ExternalDestination() => 'external',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${money(writ.amountCents)} · ${writ.purpose}',
                style: Theme.of(context).textTheme.titleMedium),
            Text('$dest · proposed by ${names[writ.byUserId] ?? writ.byUserId}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            if (mine)
              Text('Awaiting the other adventurer\'s signature.',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => ref
                        .read(householdActionsProvider)
                        ?.cancelWithdrawal(writ.proposalId),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: () => ref
                        .read(householdActionsProvider)
                        ?.approveWithdrawal(writ.proposalId),
                    child: const Text('Sign'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});

  final ChestEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final positive = entry.amountCents >= 0;
    final icon = switch (entry.kind) {
      ChestEntryKind.sliceTithe => Icons.account_balance_wallet_outlined,
      ChestEntryKind.dissolutionTithe => Icons.cancel_outlined,
      ChestEntryKind.groupLeftover => Icons.groups_outlined,
      ChestEntryKind.contribution => Icons.savings_outlined,
      ChestEntryKind.taxRefund => Icons.request_page_outlined,
      ChestEntryKind.withdrawal => Icons.north_east,
      ChestEntryKind.ransack => Icons.local_fire_department_outlined,
    };
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20),
      title: Text(entry.label),
      subtitle: Text(isoDay(entry.occurredAt)),
      trailing: Text(
        signedMoney(entry.amountCents),
        style: TextStyle(
          color: positive ? scheme.primary : scheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A drafted withdrawal from the writ sheet.
class _WritDraft {
  const _WritDraft({
    required this.amountCents,
    required this.purpose,
    required this.destination,
  });
  final int amountCents;
  final String purpose;
  final WithdrawalDestination destination;
}

class _WritSheet extends ConsumerStatefulWidget {
  const _WritSheet({required this.chestCents});
  final int chestCents;

  @override
  ConsumerState<_WritSheet> createState() => _WritSheetState();
}

class _WritSheetState extends ConsumerState<_WritSheet> {
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  String _destKind = 'external';
  String? _destUserId;

  @override
  void dispose() {
    _amount.dispose();
    _purpose.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final names = ref.watch(userNamesProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Propose a withdrawal',
              style: Theme.of(context).textTheme.titleLarge),
          Text('Chest holds ${money(widget.chestCents)}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Amount', prefixText: r'$'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _purpose,
            decoration: const InputDecoration(labelText: 'Purpose'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _destKind,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: [
              const DropdownMenuItem(value: 'external', child: Text('External')),
              if (setup != null)
                for (final p in setup.profiles)
                  DropdownMenuItem(
                    value: 'vault:${p.userId}',
                    child: Text('${names[p.userId] ?? p.name}\'s vault'),
                  ),
            ],
            onChanged: (v) => setState(() {
              if (v == null) return;
              if (v.startsWith('vault:')) {
                _destKind = 'vault';
                _destUserId = v.substring('vault:'.length);
              } else {
                _destKind = 'external';
                _destUserId = null;
              }
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submit,
            child: const Text('Propose'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final cents = tryParseMoneyCents(_amount.text);
    final purpose = _purpose.text.trim();
    if (cents == null || cents <= 0 || purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount and purpose')),
      );
      return;
    }
    final destination = _destKind == 'vault' && _destUserId != null
        ? UserVaultDestination(_destUserId!)
        : const ExternalDestination();
    Navigator.of(context).pop(_WritDraft(
      amountCents: cents,
      purpose: purpose,
      destination: destination,
    ));
  }
}
