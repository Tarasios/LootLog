/// Net worth (flag-gated): manual cash / investment / debt accounts, each with a
/// balance history sparkline, and a signed household total. "Record a balance"
/// appends a new dated sample; debts count negatively.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import 'networth_model.dart';

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
    final histories = buildAccountHistories(events);
    final total = state.netWorth.totalCents;

    return Scaffold(
      appBar: AppBar(title: const Text('Net worth')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _recordBalance(context, ref, histories),
        icon: const Icon(Icons.add),
        label: const Text('Record balance'),
      ),
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
                  Text('Total net worth',
                      style: AppText.sectionLabel(context)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    signedMoney(total),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: total >= 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (histories.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('No accounts yet. Record a balance to begin.'),
            ),
          for (final h in histories)
            _AccountCard(
              history: h,
              onAdd: () => _recordBalance(context, ref, histories,
                  presetId: h.accountId),
            ),
        ],
      ),
    );
  }

  Future<void> _recordBalance(
    BuildContext context,
    WidgetRef ref,
    List<AccountHistory> histories, {
    String? presetId,
  }) async {
    final result = await showModalBottomSheet<_BalanceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _BalanceSheet(histories: histories, presetId: presetId),
    );
    if (result != null) {
      await ref.read(householdActionsProvider)?.recordAccountBalance(
            accountId: result.accountId,
            accountName: result.name,
            kind: result.kind,
            balanceCents: result.balanceCents,
          );
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.history, required this.onAdd});

  final AccountHistory history;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kindLabel = switch (history.kind) {
      AccountKind.cash => 'Cash',
      AccountKind.investment => 'Investment',
      AccountKind.debt => 'Debt',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(history.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('$kindLabel · ${history.points.length} samples',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          )),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    signedMoney(history.signedLatestCents),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: history.kind == AccountKind.debt
                              ? scheme.error
                              : scheme.onSurface,
                        ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 96,
              height: 40,
              child: CustomPaint(
                painter: _SparklinePainter(
                  values: [for (final p in history.points) p.balanceCents],
                  color: scheme.primary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Record new balance',
              onPressed: onAdd,
              icon: const Icon(Icons.add_chart),
            ),
          ],
        ),
      ),
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
        final p = Paint()..color = color;
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, p);
      }
      return;
    }
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
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
  });
  final String? accountId;
  final String name;
  final AccountKind kind;
  final int balanceCents;
}

class _BalanceSheet extends StatefulWidget {
  const _BalanceSheet({required this.histories, this.presetId});

  final List<AccountHistory> histories;
  final String? presetId;

  @override
  State<_BalanceSheet> createState() => _BalanceSheetState();
}

class _BalanceSheetState extends State<_BalanceSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  AccountKind _kind = AccountKind.cash;

  /// The selected existing account id, or null for "new account".
  String? _accountId;

  @override
  void initState() {
    super.initState();
    final preset = widget.presetId == null
        ? null
        : widget.histories
            .where((h) => h.accountId == widget.presetId)
            .cast<AccountHistory?>()
            .firstWhere((h) => true, orElse: () => null);
    if (preset != null) {
      _accountId = preset.accountId;
      _name.text = preset.name;
      _kind = preset.kind;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
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
          Text('Record a balance',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          if (widget.histories.isNotEmpty)
            DropdownButtonFormField<String?>(
              initialValue: _accountId,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                const DropdownMenuItem(value: null, child: Text('New account…')),
                for (final h in widget.histories)
                  DropdownMenuItem(value: h.accountId, child: Text(h.name)),
              ],
              onChanged: (v) => setState(() {
                _accountId = v;
                if (v != null) {
                  final h =
                      widget.histories.firstWhere((h) => h.accountId == v);
                  _name.text = h.name;
                  _kind = h.kind;
                }
              }),
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
              ButtonSegment(value: AccountKind.cash, label: Text('Cash')),
              ButtonSegment(
                  value: AccountKind.investment, label: Text('Invest')),
              ButtonSegment(value: AccountKind.debt, label: Text('Debt')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Balance', prefixText: r'$'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _submit, child: const Text('Save')),
        ],
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
    Navigator.of(context).pop(_BalanceDraft(
      accountId: _accountId,
      name: name,
      kind: _kind,
      balanceCents: cents,
    ));
  }
}
