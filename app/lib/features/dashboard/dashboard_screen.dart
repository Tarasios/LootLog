/// The dashboard screen: composes the pure [DashboardView] from providers and
/// wires its action callbacks (open the spoils ritual, sign/decline writs).
/// On phones the activity feed rides along inside the dashboard; on desktop the
/// shell shows it in a dedicated pane, so [showActivity] is turned off there.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../data/sync/sync_service.dart';
import '../../game/skin_prefs.dart';
import '../../game/text_mode/text_adventure_screen.dart';
import '../activity/activity_model.dart';
import '../budget_setup/budget_setup_screen.dart';
import '../household_context.dart';
import '../quests/quests_screen.dart';
import '../report/report_screen.dart';
import '../spoils/spoils_screen.dart';
import 'dashboard_model.dart';
import 'dashboard_view.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.showActivity = true});

  final bool showActivity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The Adventure skin renders the same providers through the game widgets.
    // Tier 3 (text mode) is the shipping default — a first-class text adventure
    // that is complete and fun before a single sprite exists.
    if (ref.watch(appSkinProvider) == AppSkin.adventure) {
      return const TextAdventureScreen();
    }

    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    final syncStatus = ref.watch(liveSyncStatusProvider);

    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final model = buildDashboardModel(
      state,
      meUserId: meUserId,
      userNames: names,
    );
    final activity = showActivity
        ? buildActivityFeed(
            state,
            events,
            userNames: names,
            meUserId: meUserId,
            limit: 12,
          )
        : const <ActivityItem>[];

    final actions = ref.read(householdActionsProvider);
    return DashboardView(
      model: model,
      activityItems: activity,
      syncStatus: syncStatus,
      showActivity: showActivity,
      callbacks: DashboardCallbacks(
        onOpenSpoils: () => unawaited(openSpoilsRitual(context, ref)),
        onOpenReport: () => unawaited(ReportScreen.open(context)),
        onApproveWithdrawal: (id) {
          if (actions != null) unawaited(actions.approveWithdrawal(id));
        },
        onCancelWithdrawal: (id) {
          if (actions != null) unawaited(actions.cancelWithdrawal(id));
        },
        onGetStarted: () => unawaited(Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BudgetSetupScreen()),
        )),
        onNewGoal: () => unawaited(QuestEditorScreen.open(context)),
      ),
    );
  }
}
