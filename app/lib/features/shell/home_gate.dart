/// The launch gate between the budgeting ledger and the guild hall.
///
/// Until the person's play mode is known it shows a neutral [LoadingScreen].
/// Standard mode builds the plain [AppShell] and never constructs a
/// guild-hall object. Adventure opens on the Hall or the Ledger per the
/// person's Home setting, and each side gets a way across to the other.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/ui/game_home.dart';
import '../settings/play_mode.dart';
import '../settings/play_mode_providers.dart';
import 'app_shell.dart';
import 'loading_screen.dart';

/// Builds the ledger shell. [onOpenHall] is null in Standard mode (no hall
/// entry point is shown).
typedef LedgerBuilder = Widget Function(VoidCallback? onOpenHall);

Widget _appShell(VoidCallback? onOpenHall) => AppShell(onOpenHall: onOpenHall);

class HomeGate extends ConsumerWidget {
  const HomeGate({super.key, this.ledgerBuilder = _appShell});

  /// Injectable for tests; the app uses [AppShell].
  final LedgerBuilder ledgerBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(playPrefsProvider);
    if (prefs == null) return const LoadingScreen();
    if (prefs.mode == PlayMode.standard) return ledgerBuilder(null);

    final navigator = Navigator.of(context);
    switch (homeDestination(prefs)) {
      case HomeDestination.hall:
        // The ledger is pushed over the hall; its hall button pops back.
        return GameHome(
          onOpenLedger: () => navigator.push(MaterialPageRoute<void>(
            builder: (_) => ledgerBuilder(navigator.pop),
          )),
        );
      case HomeDestination.ledger:
        // The hall is pushed over the ledger; its ledger button pops back.
        return ledgerBuilder(() => navigator.push(MaterialPageRoute<void>(
              builder: (_) => GameHome(onOpenLedger: navigator.pop),
            )));
    }
  }
}
