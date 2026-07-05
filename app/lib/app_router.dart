/// The application router. go_router owns the top-level routing: first-run
/// setup versus the main shell. Sub-navigation between the shell's panes is
/// local to [AppShell]; the receipt-entry and purchase-detail flows continue to
/// use imperative navigation on top of these routes.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'data/providers.dart';
import 'features/setup/setup_screen.dart';
import 'features/shell/app_shell.dart';

/// The app's [GoRouter], rebuilt-safe and refreshed whenever first-run setup
/// completes so the redirect can send the device into the shell.
final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<bool>(ref.read(isSetUpProvider));
  ref.listen<bool>(isSetUpProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
    ],
    redirect: (context, state) {
      final setUp = ref.read(isSetUpProvider);
      final atSetup = state.matchedLocation == '/setup';
      if (!setUp) return atSetup ? null : '/setup';
      if (atSetup) return '/';
      return null;
    },
  );
});
