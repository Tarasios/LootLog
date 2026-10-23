/// The two habit actions offered besides logging a purchase — the "no spend
/// today" check-in and the weekly reconcile — shared by the guild hall's
/// Today panel and the pixel town. The logic (busy state, the reconcile
/// confirmation, the snackbar lines, the "not yet available" explanation)
/// lives here once; each surface only chooses how the button looks through
/// a [HabitActionBuilder]. Writes go through [HallHabits] (the ledger API).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hall_common.dart';
import 'hall_habits.dart';
import 'hall_home_sections.dart' show HallHomeData;
import 'hall_status.dart';

/// Why the habits are switched off on this household.
const String kHabitsUnavailableNote =
    'Check-ins and weekly reconciles switch on once your household adopts '
    'the savings rules in Settings (update every device first).';

/// Said when a habit could not be written (a failed ledger write): calm, and
/// the button is ready for another try.
const String kHabitSaveFailedNote =
    "That didn't save just now. Nothing is lost, so please try again.";

/// How one habit action reads right now.
class HabitActionView {
  const HabitActionView({
    required this.label,
    required this.icon,
    required this.done,
    required this.available,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// Already done for today / this week.
  final bool done;

  /// The household can record it (the savings rules are adopted).
  final bool available;

  /// Null while the action is disabled.
  final VoidCallback? onPressed;
}

typedef HabitActionBuilder =
    Widget Function(BuildContext context, HabitActionView action);

/// The "no spend today" check-in. With [explainWhenUnavailable] a tap on a
/// household that can't record it yet explains why (for surfaces with no
/// room for the note); otherwise the button is disabled while unavailable.
class NoSpendCheckIn extends ConsumerStatefulWidget {
  const NoSpendCheckIn({
    super.key,
    required this.data,
    required this.builder,
    this.explainWhenUnavailable = false,
  });

  final HallHomeData data;
  final HabitActionBuilder builder;
  final bool explainWhenUnavailable;

  @override
  ConsumerState<NoSpendCheckIn> createState() => _NoSpendCheckInState();
}

class _NoSpendCheckInState extends ConsumerState<NoSpendCheckIn> {
  bool _busy = false;
  bool _checkedIn = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final available = data.view.habitsAvailable;
    final covered = _checkedIn || todayCovered(data.me, data.today);
    final VoidCallback? onPressed;
    if (covered || _busy) {
      onPressed = null;
    } else if (available) {
      onPressed = _checkIn;
    } else {
      onPressed = widget.explainWhenUnavailable ? _explain : null;
    }
    return widget.builder(
      context,
      HabitActionView(
        label: covered ? 'Today already counts' : 'No spend today',
        icon: covered ? Icons.check : Icons.nights_stay_outlined,
        done: covered,
        available: available,
        onPressed: onPressed,
      ),
    );
  }

  void _explain() => ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    const SnackBar(content: Text(kHabitsUnavailableNote)),
  );

  Future<void> _checkIn() async {
    final habits = ref.read(hallHabitsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (habits == null) return;
    setState(() => _busy = true);
    final bool recorded;
    try {
      recorded = await habits.checkInNoSpend();
    } on Object {
      messenger?.showSnackBar(const SnackBar(content: Text(kHabitSaveFailedNote)));
      return;
    } finally {
      // A failed write never leaves the button stuck busy.
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() => _checkedIn = recorded);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          recorded
              ? widget.data.voice.line(
                  'noSpendDone',
                  seed: widget.data.today.toKey(),
                )
              : kHabitsUnavailableNote,
        ),
      ),
    );
  }
}

/// The weekly reconcile: asks first (or opens the ledger), then marks the
/// week done.
class WeeklyReconcile extends ConsumerStatefulWidget {
  const WeeklyReconcile({
    super.key,
    required this.data,
    required this.builder,
  });

  final HallHomeData data;
  final HabitActionBuilder builder;

  @override
  ConsumerState<WeeklyReconcile> createState() => _WeeklyReconcileState();
}

class _WeeklyReconcileState extends ConsumerState<WeeklyReconcile> {
  bool _busy = false;
  bool _reconciled = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final available = data.view.habitsAvailable;
    final reconciled = _reconciled || weekReconciled(data.me, data.today);
    return widget.builder(
      context,
      HabitActionView(
        label: reconciled ? 'Week reconciled' : 'Reconcile this week',
        icon: reconciled ? Icons.check : Icons.fact_check_outlined,
        done: reconciled,
        available: available,
        onPressed: available && !reconciled && !_busy ? _reconcile : null,
      ),
    );
  }

  Future<void> _reconcile() async {
    final habits = ref.read(hallHabitsProvider);
    if (habits == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => HallScope(
        child: AlertDialog(
          title: const Text('Reconcile this week?'),
          content: const Text(
            "Check this week's entries against your receipts or bank, add "
            'anything missing, then mark the week done.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('ledger'),
              child: const Text('Open the ledger'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop('done'),
              child: const Text('Mark reconciled'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'ledger') {
      widget.data.onOpenLedger();
      return;
    }
    if (choice != 'done') return;
    setState(() => _busy = true);
    final bool recorded;
    try {
      recorded = await habits.completeReconcile(widget.data.today);
    } on Object {
      messenger?.showSnackBar(const SnackBar(content: Text(kHabitSaveFailedNote)));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    setState(() => _reconciled = recorded);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          recorded
              ? widget.data.voice.line(
                  'reconcileDone',
                  seed: widget.data.today.weekStart.toKey(),
                )
              : kHabitsUnavailableNote,
        ),
      ),
    );
  }
}
