/// The status dashboard: a pure widget rendering a [DashboardModel] into a
/// designed set of cards. It owns no state and reads no providers, so it is
/// golden-testable at any size. The screen wrapper supplies the model, activity
/// items, sync status, and the action callbacks.
///
/// Layout is responsive: on a phone-width viewport it is one scrolling column;
/// past [kDashboardWideBreakpoint] the month hero spans the top and the
/// remaining cards split into a primary/secondary two-column grid.
///
/// This file holds the layout and the helpers the cards share; each card (with
/// its private tiles) is a part file under `cards/`.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../ui/category_palette.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_card.dart';
import '../../ui/widgets/progress_ring.dart';
import '../activity/activity_model.dart';
import '../activity/activity_view.dart';
import '../networth/networth_model.dart';
import '../spoils/spoils_model.dart';
import '../sync/sync_status.dart';
import '../warchest/pending_advance_tile.dart';
import 'dashboard_model.dart';

part 'cards/advances_card.dart';
part 'cards/categories_card.dart';
part 'cards/emergency_funds_card.dart';
part 'cards/get_started_card.dart';
part 'cards/hero_card.dart';
part 'cards/maintenance_card.dart';
part 'cards/net_worth_card.dart';
part 'cards/overbudget_banner.dart';
part 'cards/quests_card.dart';
part 'cards/spoils_banner.dart';
part 'cards/timeline_card.dart';
part 'cards/upcoming_card.dart';
part 'cards/vacation_card.dart';
part 'cards/vault_card.dart';
part 'cards/war_chest_card.dart';

/// At or above this width the dashboard becomes a two-column grid.
const double kDashboardWideBreakpoint = 720;

/// Callbacks the dashboard needs; defaulted to no-ops so goldens can omit them.
class DashboardCallbacks {
  const DashboardCallbacks({
    this.onOpenSpoils,
    this.onOpenReport,
    this.onApproveWithdrawal,
    this.onCancelWithdrawal,
    this.onGetStarted,
    this.onNewGoal,
    this.onApproveAdvance,
    this.onCancelAdvance,
    this.onOpenVacations,
  });

  final VoidCallback? onOpenSpoils;

  /// Opens the monthly spend report. Null in goldens (button hidden).
  final VoidCallback? onOpenReport;
  final void Function(String proposalId)? onApproveWithdrawal;
  final void Function(String proposalId)? onCancelWithdrawal;

  /// Opens budget setup from the new-household empty state.
  final VoidCallback? onGetStarted;

  /// Opens the new savings-goal editor. Null in goldens (button hidden).
  final VoidCallback? onNewGoal;

  /// Approves / declines-or-withdraws a pending borrowing request.
  final void Function(String advanceId)? onApproveAdvance;
  final void Function(String advanceId)? onCancelAdvance;

  /// Opens the vacations screen from an open-trip card.
  final VoidCallback? onOpenVacations;
}

class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.model,
    this.activityItems = const [],
    this.syncStatus = SyncStatus.localOnly,
    this.showActivity = true,
    this.callbacks = const DashboardCallbacks(),
  });

  final DashboardModel model;
  final List<ActivityItem> activityItems;
  final SyncStatus syncStatus;

  /// On desktop the activity feed lives in its own pane, so the dashboard omits
  /// the inline activity section.
  final bool showActivity;
  final DashboardCallbacks callbacks;

  /// A household with no slices and no quests has never been set up.
  bool get _isNewHousehold => model.slices.isEmpty && model.quests.isEmpty;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= kDashboardWideBreakpoint;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.huge,
          ),
          children: wide ? _wide(context) : _narrow(context),
        );
      },
    );
  }

  // ---- Section builders --------------------------------------------------

  Widget _hero(BuildContext context) => _HeroCard(
        model: model,
        syncStatus: syncStatus,
        onOpenReport: callbacks.onOpenReport,
      );

  List<Widget> _topFullWidth(BuildContext context) => [
        if (_isNewHousehold) _GetStartedCard(onGetStarted: callbacks.onGetStarted),
        for (final debt in model.overbudgets)
          _OverbudgetBanner(card: debt, onOpen: callbacks.onOpenSpoils),
        if (model.spoils != null)
          _SpoilsBanner(ritual: model.spoils!, onOpen: callbacks.onOpenSpoils),
        if (model.advances.isNotEmpty)
          _AdvancesCard(advances: model.advances, callbacks: callbacks),
        for (final vacation in model.vacations)
          _VacationCard(vacation: vacation, onOpen: callbacks.onOpenVacations),
      ];

  /// The primary column: what you spend and what's coming.
  List<Widget> _primary(BuildContext context) => [
        _CategoriesCard(rings: model.slices),
        _TimelineCard(timeline: model.timeline),
        if (model.upcoming.isNotEmpty) _UpcomingCard(items: model.upcoming),
      ];

  /// The secondary column: goals, pouches, and reserves.
  List<Widget> _secondary(BuildContext context) => [
        _QuestsCard(quests: model.quests, onNewGoal: callbacks.onNewGoal),
        _VaultCard(
          vault: model.vault,
          meName: model.meName,
          label: Glossary.vaultLabel(
            isAdventure: false,
            savingsRules: model.savingsRules,
          ),
        ),
        _WarChestCard(card: model.warChest, callbacks: callbacks),
        if (model.netWorth.show) _NetWorthCard(summary: model.netWorth),
        if (model.maintenance.isNotEmpty) _MaintenanceCard(items: model.maintenance),
        if (model.emergencyFunds.isNotEmpty)
          _EmergencyFundsCard(funds: model.emergencyFunds),
      ];

  List<Widget> _activity(BuildContext context) => [
        if (showActivity && activityItems.isNotEmpty)
          AppCard(
            child: ActivityFeedView(
              items: activityItems,
              padding: EdgeInsets.zero,
              header: true,
              embedded: true,
            ),
          ),
      ];

  // ---- Narrow (phone): one column ---------------------------------------
  List<Widget> _narrow(BuildContext context) {
    return _gap([
      _hero(context),
      ..._topFullWidth(context),
      ..._primary(context),
      ..._secondary(context),
      ..._activity(context),
    ]);
  }

  // ---- Wide (desktop): hero on top, two columns below -------------------
  List<Widget> _wide(BuildContext context) {
    return _gap([
      _hero(context),
      ..._topFullWidth(context),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(children: _gap(_primary(context))),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Column(
              children: _gap([..._secondary(context), ..._activity(context)]),
            ),
          ),
        ],
      ),
    ]);
  }
}

/// A glossary term's plain (Classic) label, capitalized for a heading. The
/// dashboard is the Classic surface; Adventure renders its own dashboard.
String _plain(GlossaryTerm term) {
  final classicTerm = term.classic;
  return classicTerm.isEmpty ? classicTerm : classicTerm[0].toUpperCase() + classicTerm.substring(1);
}

/// Inserts a uniform vertical gap between a list of stacked cards.
List<Widget> _gap(List<Widget> children) {
  final out = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    if (i > 0) out.add(const SizedBox(height: AppSpacing.md));
    out.add(children[i]);
  }
  return out;
}

Widget _tag(BuildContext context, String text) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
    decoration: BoxDecoration(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.chip,
    ),
    child: Text(
      text,
      style: Theme.of(context)
          .textTheme
          .labelSmall
          ?.copyWith(color: scheme.onTertiaryContainer),
    ),
  );
}

