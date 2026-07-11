/// The responsive app shell. On a narrow (Android) window it is a single pane
/// with bottom navigation across Dashboard / Ledger / Activity. On a wide
/// (desktop) window it becomes a navigation rail plus a two-pane layout: the
/// selected pane (slices or ledger) on the left and the activity feed always
/// visible on the right.
///
/// The quick-entry FAB and receipt scan live here so every pane shares them.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/budget_workbook.dart';
import '../../data/providers.dart';
import '../../data/sheets/sheets_provider.dart';
import '../../data/sync/sync_service.dart';
import '../../ui/theme.dart';
import '../activity/activity_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/expense_entry_screen.dart';
import '../ledger/ledger_screen.dart';
import '../homestead/homestead_screen.dart';
import '../menu/manage_screen.dart';
import '../ocr/ocr_confirm_screen.dart';
import '../quests/quests_screen.dart';
import '../rewards/trophy_hall_screen.dart';
import '../spoils/spoils_screen.dart';
import '../warchest/warchest_screen.dart';
import '../sync/sync_status.dart';
import '../tutorial/tutorial.dart';

/// The width at or above which the shell switches to the rail + two-pane layout.
const double kWideBreakpoint = 840;

/// The main panes reachable from navigation. Goals, the war chest, the trophy
/// hall and the homestead are first-class destinations (not buried in Manage);
/// the narrow layout surfaces Goals directly and keeps the rest one tap away.
enum ShellPane { dashboard, ledger, goals, warchest, trophies, homestead, activity }

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialPane = ShellPane.dashboard});

  final ShellPane initialPane;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late ShellPane _pane = widget.initialPane;

  void _select(ShellPane pane) => setState(() => _pane = pane);

  Widget _paneBody(ShellPane pane, {required bool showActivity}) {
    switch (pane) {
      case ShellPane.dashboard:
        return DashboardScreen(showActivity: showActivity);
      case ShellPane.ledger:
        return const LedgerScreen();
      case ShellPane.goals:
        return const QuestsScreen();
      case ShellPane.warchest:
        return const WarChestScreen();
      case ShellPane.trophies:
        return const TrophyHallScreen();
      case ShellPane.homestead:
        return const HomesteadScreen();
      case ShellPane.activity:
        return const ActivityScreen();
    }
  }

  String get _title => switch (_pane) {
        ShellPane.dashboard => 'LootLog',
        ShellPane.ledger => 'Ledger',
        ShellPane.goals => 'Savings goals',
        ShellPane.warchest => 'War chest',
        ShellPane.trophies => 'Trophy hall',
        ShellPane.homestead => 'Homestead',
        ShellPane.activity => 'Activity',
      };

  @override
  Widget build(BuildContext context) {
    // Optionally push the workbook to Google Sheets after a successful sync.
    // The gate does nothing unless the user has opted in (and a client is
    // available), so this is a quiet no-op by default.
    ref.listen<SyncStatus>(liveSyncStatusProvider, (prev, next) {
      if (next == SyncStatus.synced && prev != SyncStatus.synced) {
        unawaited(_pushSheetsAfterSync());
      }
    });
    final wide = MediaQuery.of(context).size.width >= kWideBreakpoint;
    return TutorialGate(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN): () =>
              ExpenseEntryScreen.open(context),
        },
        child: Focus(
          autofocus: true,
          child: wide ? _buildWide(context) : _buildNarrow(context),
        ),
      ),
    );
  }

  // ---- Narrow: bottom navigation, single pane ---------------------------
  Widget _buildNarrow(BuildContext context) {
    // On phones the dashboard folds the activity feed into itself. The bottom
    // bar carries the four everyday panes; war chest / trophies / homestead
    // stay one tap away in Manage.
    const tabs = [
      ShellPane.dashboard,
      ShellPane.ledger,
      ShellPane.goals,
      ShellPane.activity,
    ];
    final index = tabs.contains(_pane) ? tabs.indexOf(_pane) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          const SpoilsEntryButton(),
          IconButton(
            tooltip: 'Manage',
            icon: const Icon(Icons.menu),
            onPressed: () => ManageScreen.open(context),
          ),
        ],
      ),
      body: _paneBody(_pane, showActivity: true),
      floatingActionButton: _fab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _select(tabs[i]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ledger',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Activity',
          ),
        ],
      ),
    );
  }

  // ---- Wide: navigation rail, two panes (slices | activity) -------------
  Widget _buildWide(BuildContext context) {
    // The rail switches the left pane; activity is pinned on the right.
    const leftPanes = [
      ShellPane.dashboard,
      ShellPane.ledger,
      ShellPane.goals,
      ShellPane.warchest,
      ShellPane.trophies,
      ShellPane.homestead,
    ];
    final railIndex =
        leftPanes.contains(_pane) ? leftPanes.indexOf(_pane) : 0;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          const SpoilsEntryButton(),
          IconButton(
            tooltip: 'Manage',
            icon: const Icon(Icons.menu),
            onPressed: () => ManageScreen.open(context),
          ),
        ],
      ),
      floatingActionButton: _fab(context),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: railIndex,
            onDestinationSelected: (i) => _select(leftPanes[i]),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Ledger'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag),
                label: Text('Goals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_outlined),
                selectedIcon: Icon(Icons.account_balance),
                label: Text('War chest'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Trophies'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.cottage_outlined),
                selectedIcon: Icon(Icons.cottage),
                label: Text('Homestead'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _paneBody(
              _pane == ShellPane.activity ? ShellPane.dashboard : _pane,
              showActivity: false,
            ),
          ),
          Container(width: 1, color: scheme.outlineVariant),
          const SizedBox(
            width: 360,
            child: ActivityScreen(),
          ),
        ],
      ),
    );
  }

  /// Builds the current workbook and hands it to the isolated Sheets gate,
  /// which only pushes when the user has enabled "also push after each sync".
  Future<void> _pushSheetsAfterSync() async {
    final state = ref.read(householdStateProvider).value;
    if (state == null) return;
    final store = ref.read(sheetsSyncStoreProvider);
    final settings = await store.loadSettings();
    if (!settings.pushAfterSync) return;
    final workbook = buildBudgetWorkbook(
      state,
      userNames: {for (final m in state.members.values) m.memberId: m.name},
    );
    await ref.read(sheetsSyncServiceProvider).maybePushAfterSync(
          workbook,
          settings: settings,
          credentials: await store.loadCredentials(),
        );
  }

  Widget _fab(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'scan',
          onPressed: () => captureReceiptAndConfirm(context, ref),
          tooltip: 'Scan a receipt',
          child: const Icon(Icons.document_scanner_outlined),
        ),
        const SizedBox(width: AppSpacing.md),
        FloatingActionButton.extended(
          heroTag: 'new',
          onPressed: () => ExpenseEntryScreen.open(context),
          icon: const Icon(Icons.add),
          label: const Text('New'),
        ),
      ],
    );
  }
}
