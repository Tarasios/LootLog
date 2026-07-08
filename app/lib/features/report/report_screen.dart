/// The month-end spend report screen: wires the pure [ReportView] to providers,
/// holding the selected month and scope (household or a single adult). Reachable
/// from the dashboard header and shown after the month-close ritual. It reads the
/// report projection from the reducer via [buildMonthReport] — no money math
/// lives here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/report.dart';
import '../../domain/time.dart';
import '../../ui/format.dart';
import '../household_context.dart';
import 'report_view.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.initialMonth});

  /// The month to open on; defaults to the current household month.
  final Month? initialMonth;

  static Future<void> open(BuildContext context, {Month? initialMonth}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ReportScreen(initialMonth: initialMonth),
      ));

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  late Month _month = widget.initialMonth ?? Month.fromInstant(DateTime.now());

  /// null = household; otherwise an adult user id.
  String? _scope;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final adults = state.adultIds.toList()
      ..sort((a, b) => (names[a] ?? a).compareTo(names[b] ?? b));
    // A scope that no longer exists (e.g. after a member change) falls back.
    if (_scope != null && !adults.contains(_scope)) _scope = null;

    final report = buildMonthReport(state, _month, userId: _scope);
    final scopes = <ReportScope>[
      const ReportScope(userId: null, label: 'Household'),
      for (final a in adults)
        ReportScope(userId: a, label: names[a] ?? 'Adult'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Monthly report')),
      body: ReportView(
        report: report,
        monthLabel: monthLabel(_month.year, _month.month),
        scopes: scopes,
        onPrevMonth: () => setState(() => _month = _month.prev()),
        onNextMonth: () => setState(() => _month = _month.next()),
        onScopeChanged: (u) => setState(() => _scope = u),
      ),
    );
  }
}
