/// The household-visibility toggle: whether this device's dashboards show
/// the other adults' personal budgets, monsters, and OVERBUDGETs alongside
/// its own.
///
/// This is a per-device DISPLAY preference, not privacy: the household's
/// event log still syncs in full to every device (there are no private
/// ledgers), and shared surfaces — group categories, the war chest, writs,
/// ransacks — always show. Defaults to full visibility.
library;

// Tiny deliberate file IO; async keeps it off the UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _file() async => File(
    p.join((await getApplicationDocumentsDirectory()).path,
        'show_household_budgets.txt'));

/// Loads the persisted choice; defaults to true (full mutual visibility).
Future<bool> loadShowHouseholdBudgets() async {
  final f = await _file();
  if (!await f.exists()) return true;
  return (await f.readAsString()).trim() != 'off';
}

Future<void> saveShowHouseholdBudgets(bool value) async {
  final f = await _file();
  await f.writeAsString(value ? 'on' : 'off', flush: true);
}

class ShowHouseholdBudgets extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    final loaded = await loadShowHouseholdBudgets();
    if (loaded != state) state = loaded;
  }

  Future<void> select(bool value) async {
    state = value;
    await saveShowHouseholdBudgets(value);
  }
}

/// Whether this device shows other adults' personal budgets and debts.
final showHouseholdBudgetsProvider =
    NotifierProvider<ShowHouseholdBudgets, bool>(ShowHouseholdBudgets.new);
