/// The launch gate between the budgeting ledger and the guild hall.
///
/// Until the person's play mode is known it shows a neutral [LoadingScreen].
/// Standard mode builds the plain [AppShell] and never constructs a
/// guild-hall object. Adventure opens on the Hall or the Ledger per the
/// person's Home setting, and each side gets a way across to the other.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../game/ui/game_home.dart';
import '../budget_setup/budget_setup_screen.dart';
import '../entry/expense_entry_screen.dart';
import '../household_context.dart';
import '../report/report_screen.dart';
import '../settings/play_mode.dart';
import '../settings/play_mode_providers.dart';
import '../spoils/spoils_model.dart';
import '../spoils/spoils_screen.dart';
import 'app_shell.dart';
import 'loading_screen.dart';

/// Builds the ledger shell. [onOpenHall] is null in Standard mode (no hall
/// entry point is shown).
typedef LedgerBuilder = Widget Function(VoidCallback? onOpenHall);

Widget _appShell(VoidCallback? onOpenHall) => AppShell(onOpenHall: onOpenHall);

/// The ledger screens the guild hall links into: quick entry, and one
/// screen per spoils-ritual step (the ritual's real work happens there).
HallLinks ledgerHallLinks(WidgetRef ref, VoidCallback openLedger) => HallLinks(
      logPurchase: ExpenseEntryScreen.open,
      reconcileMonth: (context, month) => openLedger(),
      reviewMonth: (context, month) =>
          ReportScreen.open(context, initialMonth: month),
      planMonth: (context, month) => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const BudgetSetupScreen())),
      divideLeftovers: (context, month) {
        final state = ref.read(householdStateProvider).value;
        final me = ref.read(meUserIdProvider);
        final pending = state != null &&
            me != null &&
            buildSpoilsRitual(state,
                    meUserId: me, userNames: ref.read(userNamesProvider)) !=
                null;
        if (!pending) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
              content: Text('Nothing is waiting to be divided right now: '
                  'the leftovers are already settled.')));
          return;
        }
        unawaited(openSpoilsRitual(context, ref));
      },
    );

class HomeGate extends ConsumerWidget {
  const HomeGate({
    super.key,
    this.ledgerBuilder = _appShell,
    this.hallLinks = ledgerHallLinks,
  });

  /// Injectable for tests; the app uses [AppShell].
  final LedgerBuilder ledgerBuilder;

  /// The hall's links into the ledger. Injectable for tests.
  final HallLinks Function(WidgetRef ref, VoidCallback openLedger) hallLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(playPrefsProvider);
    if (prefs == null) return const LoadingScreen();
    if (prefs.mode == PlayMode.standard) return ledgerBuilder(null);

    final navigator = Navigator.of(context);
    switch (homeDestination(prefs)) {
      case HomeDestination.hall:
        // The ledger is pushed over the hall; its hall button pops back.
        void openLedger() => navigator.push(MaterialPageRoute<void>(
              builder: (_) => ledgerBuilder(navigator.pop),
            ));
        return GameHome(
          onOpenLedger: openLedger,
          links: hallLinks(ref, openLedger),
        );
      case HomeDestination.ledger:
        // The hall is pushed over the ledger; its ledger button pops back.
        return ledgerBuilder(() => navigator.push(MaterialPageRoute<void>(
              builder: (_) => GameHome(
                onOpenLedger: navigator.pop,
                links: hallLinks(ref, navigator.pop),
              ),
            )));
    }
  }
}
