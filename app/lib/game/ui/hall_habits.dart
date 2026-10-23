/// The two ledger-side habit actions the hall offers besides logging a
/// purchase: the "no spend today" check-in and the weekly reconcile. Both go
/// through the existing ledger API ([HouseholdActions]); the hall never writes
/// ledger events itself. Behind a small interface so widget tests can fake it.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../domain/time.dart';

abstract interface class HallHabits {
  /// Records "nothing spent today". False when the household can't record it
  /// yet (the savings rules aren't adopted).
  Future<bool> checkInNoSpend();

  /// Marks the week containing [day] reconciled. False when unavailable.
  Future<bool> completeReconcile(CalendarDay day);
}

class _LedgerHabits implements HallHabits {
  const _LedgerHabits(this._actions);

  final HouseholdActions _actions;

  @override
  Future<bool> checkInNoSpend() => _actions.checkInNoSpend();

  @override
  Future<bool> completeReconcile(CalendarDay day) =>
      _actions.completeReconcile(day);
}

/// The habit actions for this device's adult, or null before setup.
final hallHabitsProvider = Provider<HallHabits?>(
  (ref) {
    final actions = ref.watch(householdActionsProvider);
    return actions == null ? null : _LedgerHabits(actions);
  },
  dependencies: [householdActionsProvider],
);
