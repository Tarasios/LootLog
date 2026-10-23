/// Net worth (flag-gated): tracked savings / investment / debt accounts, each
/// with a balance-history sparkline and a read-time current value (savings/debt
/// accrue interest; investments go stale). The header shows assets − debts.
/// "Record a balance" appends a dated sample and the account's config; "Record a
/// transfer" appends a deposit/withdrawal. Debts count negatively.
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
import 'networth_model.dart';

String _kindLabel(AccountKind kind) => switch (kind) {
      AccountKind.savings => 'Savings',
      AccountKind.cash => 'Cash',
      AccountKind.investment => 'Investment',
      AccountKind.debt => 'Debt',
    };

String _cadenceLabel(AccountCadence cadence) => switch (cadence) {
      AccountCadence.daily => 'Daily',
      AccountCadence.monthly => 'Monthly',
      AccountCadence.quarterly => 'Quarterly',
      AccountCadence.annually => 'Annually',
    };

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!state.netWorth.show) {
      return Scaffold(
        appBar: AppBar(title: const Text('Net worth')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Text('Enable "Show net worth" in Settings first.'),
          ),
        ),
      );
    }
    final histories = {
      for (final history in buildAccountHistories(events)) history.accountId: history,
    };
    final netWorth = state.netWorth;
    final accounts = netWorth.accounts.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    final stale = netWorth.staleAccounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordBalance(context, ref, accounts),
        icon: const Icon(Icons.add),
        label: const Text('Record balance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _TotalCard(netWorth: netWorth),
          const SizedBox(height: AppSpacing.lg),
          if (stale.isNotEmpty) ...[
            _StaleBanner(accounts: stale),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (accounts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No accounts yet. Record a balance to begin.'),
            ),
          for (final account in accounts)
            _AccountCard(
              account: account,
              history: histories[account.accountId],
              onBalance: () =>
                  _recordBalance(context, ref, accounts, presetId: account.accountId),
              onTransfer: () => _recordTransfer(context, ref, account),
            ),
        ],
      ),
    );
  }

  Future<void> _recordBalance(
    BuildContext context,
    WidgetRef ref,
    List<AccountBalance> accounts, {
    String? presetId,
  }) async {
    final result = await showModalBottomSheet<_BalanceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _BalanceSheet(accounts: accounts, presetId: presetId),
    );
    if (result == null) return;
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;
    final id = await actions.setTrackedAccount(
      accountId: result.accountId,
      name: result.name,
      kind: result.kind,
      aprBps: result.aprBps,
      accrualCadence: result.accrualCadence,
      updateCadence: result.updateCadence,
      minPaymentCents: result.minPaymentCents,
    );
    await actions.recordAccountBalance(
      accountId: id,
      accountName: result.name,
      kind: result.kind,
      balanceCents: result.balanceCents,
    );
  }

  Future<void> _recordTransfer(
    BuildContext context,
    WidgetRef ref,
    AccountBalance account,
  ) async {
    final result = await showModalBottomSheet<_TransferDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TransferSheet(account: account),
    );
    if (result == null) return;
    await ref.read(householdActionsProvider)?.recordAccountTransfer(
          accountId: account.accountId,
          amountCents: result.amountCents,
          direction: result.direction,
          note: result.note,
        );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.netWorth});

  final NetWorthState netWorth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total net worth', style: AppText.sectionLabel(context)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              signedMoney(netWorth.totalCents),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: netWorth.totalCents >= 0 ? scheme.primary : scheme.error,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _Tally(
                    label: 'Assets',
                    value: money(netWorth.assetsCents),
                    color: scheme.primary,
                  ),
                ),
                Expanded(
                  child: _Tally(
                    label: 'Debts',
                    value: netWorth.debtsCents == 0
                        ? money(0)
                        : '−${money(netWorth.debtsCents)}',
                    color: scheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tally extends StatelessWidget {
  const _Tally({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color)),
      ],
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.accounts});

  final List<AccountBalance> accounts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final names = accounts.map((account) => account.name).join(', ');
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.update, color: scheme.onTertiaryContainer),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Update requested: $names ${accounts.length == 1 ? 'is' : 'are'} '
                'stale. Record a fresh balance to keep net worth honest.',
                style: TextStyle(color: scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.history,
    required this.onBalance,
    required this.onTransfer,
  });

  final AccountBalance account;
  final AccountHistory? history;
  final VoidCallback onBalance;
  final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final points = history?.points ?? const <BalancePoint>[];
    final subtitleParts = <String>[
      _kindLabel(account.kind),
      '${points.length} sample${points.length == 1 ? '' : 's'}',
    ];
    if (account.accruedInterestCents != 0) {
      subtitleParts.add('+${money(account.accruedInterestCents)} interest');
    }
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(account.name,
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                          ),
                          if (account.stale) ...[
                            const SizedBox(width: AppSpacing.sm),
                            _StaleChip(),
                          ],
                        ],
                      ),
                      Text(subtitleParts.join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        signedMoney(account.signedCents),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: account.isDebt
                                  ? scheme.error
                                  : scheme.onSurface,
                            ),
                      ),
                      if (account.minPaymentCents != null &&
                          account.minPaymentCents! > 0)
                        Text(
                          'Min payment ${money(account.minPaymentCents!)}/mo',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  height: 40,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values: [for (final point in points) point.balanceCents],
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onTransfer,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('Transfer'),
                ),
                TextButton.icon(
                  onPressed: onBalance,
                  icon: const Icon(Icons.add_chart, size: 18),
                  label: const Text('Balance'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StaleChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('stale',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onTertiaryContainer,
              )),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      // A single point: draw a flat baseline dot.
      if (values.length == 1) {
        final paint = Paint()..color = color;
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, paint);
      }
      return;
    }
    final minV = values.reduce((first, second) => first < second ? first : second);
    final maxV = values.reduce((first, second) => first > second ? first : second);
    final span = (maxV - minV) == 0 ? 1 : (maxV - minV);
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = dx * i;
      final norm = (values[i] - minV) / span;
      final y = size.height - norm * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _BalanceDraft {
  const _BalanceDraft({
    required this.accountId,
    required this.name,
    required this.kind,
    required this.balanceCents,
    this.aprBps,
    this.accrualCadence,
    this.updateCadence,
    this.minPaymentCents,
  });
  final String? accountId;
  final String name;
  final AccountKind kind;
  final int balanceCents;
  final int? aprBps;
  final AccountCadence? accrualCadence;
  final AccountCadence? updateCadence;
  final int? minPaymentCents;
}

class _BalanceSheet extends StatefulWidget {
  const _BalanceSheet({required this.accounts, this.presetId});

  final List<AccountBalance> accounts;
  final String? presetId;

  @override
  State<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<_BalanceSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _apr = TextEditingController();
  final _minPayment = TextEditingController();
  AccountKind _kind = AccountKind.savings;
  AccountCadence _accrualCadence = AccountCadence.monthly;
  AccountCadence _updateCadence = AccountCadence.monthly;

  /// The selected existing account id, or null for "new account".
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final preset = widget.presetId == null
        ? null
        : widget.accounts
            .where((account) => account.accountId == widget.presetId)
            .cast<AccountBalance?>()
            .firstWhere((account) => true, orElse: () => null);
    if (preset != null) {
      _accountId = preset.accountId;
      _name.text = preset.name;
      _kind = preset.kind;
      if (preset.aprBps != null) {
        _apr.text = (preset.aprBps! / 100).toString();
      }
      if (preset.accrualCadence != null) {
        _accrualCadence = preset.accrualCadence!;
      }
      if (preset.updateCadence != null) {
        _updateCadence = preset.updateCadence!;
      }
      if (preset.minPaymentCents != null) {
        _minPayment.text = (preset.minPaymentCents! / 100).toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _apr.dispose();
    _minPayment.dispose();
    super.dispose();
  }

  void _selectExisting(String? id) {
    setState(() {
      _accountId = id;
      if (id != null) {
        final selected = widget.accounts.firstWhere((account) => account.accountId == id);
        _name.text = selected.name;
        _kind = selected.kind;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final accrues =
        _kind == AccountKind.savings || _kind == AccountKind.debt;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Record a balance',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            if (widget.accounts.isNotEmpty)
              DropdownButtonFormField<String?>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Account'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('New account…')),
                  for (final account in widget.accounts)
                    DropdownMenuItem(
                        value: account.accountId, child: Text(account.name)),
                ],
                onChanged: _selectExisting,
              ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Account name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedButton<AccountKind>(
              segments: const [
                ButtonSegment(
                    value: AccountKind.savings, label: Text('Savings')),
                ButtonSegment(
                    value: AccountKind.investment, label: Text('Invest')),
                ButtonSegment(value: AccountKind.debt, label: Text('Debt')),
              ],
              selected: {_kind},
              onSelectionChanged: (selection) => setState(() => _kind = selection.first),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Balance', prefixText: r'$'),
            ),
            const SizedBox(height: AppSpacing.md),
            if (accrues) ...[
              TextField(
                controller: _apr,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Interest rate (APR)',
                  suffixText: '%',
                  helperText: 'Optional; accrues at read time.',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _CadenceDropdown(
                label: 'Compounding',
                value: _accrualCadence,
                onChanged: (cadence) => setState(() => _accrualCadence = cadence),
              ),
            ],
            if (_kind == AccountKind.investment)
              _CadenceDropdown(
                label: 'Update reminder',
                value: _updateCadence,
                onChanged: (cadence) => setState(() => _updateCadence = cadence),
              ),
            if (_kind == AccountKind.debt) ...[
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _minPayment,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Minimum payment',
                  prefixText: r'$',
                  helperText:
                      'Optional; surfaces as a monthly recurring expense.',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  void _submit() {
    final name = _name.text.trim();
    final cents = tryParseMoneyCents(_amount.text);
    if (name.isEmpty || cents == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an account name and balance')),
      );
      return;
    }
    final accrues =
        _kind == AccountKind.savings || _kind == AccountKind.debt;
    final aprPct = double.tryParse(_apr.text.trim());
    final minPayment = tryParseMoneyCents(_minPayment.text);
    Navigator.of(context).pop(_BalanceDraft(
      accountId: _accountId,
      name: name,
      kind: _kind,
      balanceCents: cents,
      aprBps: accrues && aprPct != null ? (aprPct * 100).round() : null,
      accrualCadence: accrues && aprPct != null ? _accrualCadence : null,
      updateCadence:
          _kind == AccountKind.investment ? _updateCadence : null,
      minPaymentCents: _kind == AccountKind.debt ? minPayment : null,
    ));
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
          DropdownMenuItem(value: cadence, child: Text(_cadenceLabel(cadence))),
      ],
      onChanged: (cadence) {
        if (cadence != null) onChanged(cadence);
      },
    );
  }
}

class _TransferDraft {
  const _TransferDraft({
    required this.amountCents,
    required this.direction,
    this.note,
  });
  final int amountCents;
  final TransferDirection direction;
  final String? note;
}

class _TransferSheet extends StatefulWidget {
  const _TransferSheet({required this.account});

  final AccountBalance account;

  @override
  State<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends State<_TransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  TransferDirection _direction = TransferDirection.deposit;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Transfer · ${widget.account.name}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          SegmentedButton<TransferDirection>(
            segments: const [
              ButtonSegment(
                  value: TransferDirection.deposit, label: Text('Deposit')),
              ButtonSegment(
                  value: TransferDirection.withdrawal,
                  label: Text('Withdraw')),
            ],
            selected: {_direction},
            onSelectionChanged: (selection) => setState(() => _direction = selection.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Amount', prefixText: r'$'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
      ),
    );
  }

  void _submit() {
    final cents = tryParseMoneyCents(_amount.text);
    if (cents == null || cents <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a transfer amount')),
      );
      return;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(_TransferDraft(
      amountCents: cents,
      direction: _direction,
      note: note.isEmpty ? null : note,
    ));
  }
}
