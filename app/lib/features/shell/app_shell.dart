/// The responsive app shell. On a narrow (Android) window it is a single pane
/// with bottom navigation across Dashboard / Ledger / Goals / Funds / Activity.
/// On a wide (desktop) window it becomes a navigation rail (Dashboard / Ledger
/// / Goals / Funds / Trophies) plus a two-pane layout: the selected pane on
/// the left and the activity feed always visible on the right.
///
/// Funds (Adventure: Treasury) is the hub for the war chest, emergency funds,
/// vacations and the homestead, so none of them hide behind Manage; the
/// trophy hall is also one tap from the Goals pane on every width.
///
/// The quick-entry FAB and receipt scan live here so every pane shares them,
/// as does the overflow menu holding the Adventure / Standard switch (in both
/// modes — the Adventure dashboards render inside this shell).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/budget_workbook.dart';
import '../../data/providers.dart';
import '../../data/sheets/sheets_provider.dart';
import '../../data/sync/sync_service.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../activity/activity_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../entry/expense_entry_screen.dart';
import '../funds/funds_screen.dart';
import '../ledger/ledger_screen.dart';
import '../menu/manage_screen.dart';
import '../ocr/ocr_confirm_screen.dart';
import '../quests/quests_screen.dart';
import '../rewards/trophy_hall_screen.dart';
import '../settings/play_mode_providers.dart';
import '../settings/play_mode_switch.dart';
import '../spoils/spoils_screen.dart';
import '../sync/sync_status.dart';
import '../tutorial/tutorial.dart';

/// The width at or above which the shell switches to the rail + two-pane layout.
const double kWideBreakpoint = 840;

/// The main panes reachable from navigation. Goals and Funds (the hub for the
/// war chest, emergency funds, vacations and the homestead) are first-class
/// on every width; the trophy hall has its own rail slot on desktop and sits
/// one tap from Goals on phones.
enum ShellPane { dashboard, ledger, goals, funds, trophies, activity }

/// The bottom-bar panes on a phone. The dashboard folds a short activity feed
/// in, but the full feed keeps its own tab.
const kNarrowPanes = [
  ShellPane.dashboard,
  ShellPane.ledger,
  ShellPane.goals,
  ShellPane.funds,
  ShellPane.activity,
];

/// The rail panes on desktop; activity is pinned in its own right-hand pane.
const kWidePanes = [
  ShellPane.dashboard,
  ShellPane.ledger,
  ShellPane.goals,
  ShellPane.funds,
  ShellPane.trophies,
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    super.key,
    this.initialPane = ShellPane.dashboard,
    this.onOpenHall,
  });

  final ShellPane initialPane;

  /// Opens the guild hall. Set only for Adventure-mode users (by the home
  /// gate); null in Standard mode, where no hall entry point is shown.
  final VoidCallback? onOpenHall;

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
      case ShellPane.funds:
        return const FundsScreen();
      case ShellPane.trophies:
        return const TrophyHallScreen();
      case ShellPane.activity:
        return const ActivityScreen();
    }
  }

  /// "Funds" in Standard, "Treasury" in Adventure (from the glossary).
  String _fundsLabel(bool adventure) =>
      Glossary.funds.label(isAdventure: adventure);

  String _title(bool adventure) => switch (_pane) {
    ShellPane.dashboard => 'LootLog',
    ShellPane.ledger => 'Ledger',
    ShellPane.goals => 'Savings goals',
    ShellPane.funds => _fundsLabel(adventure),
    ShellPane.trophies => 'Trophy hall',
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
    final adventure = ref.watch(isAdventureProvider);
    final wide = MediaQuery.of(context).size.width >= kWideBreakpoint;
    return TutorialGate(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyN): () =>
              ExpenseEntryScreen.open(context),
        },
        child: Focus(
          autofocus: true,
          child: wide
              ? _buildWide(context, adventure)
              : _buildNarrow(context, adventure),
        ),
      ),
    );
  }

  // ---- Narrow: bottom navigation, single pane ---------------------------
  Widget _buildNarrow(BuildContext context, bool adventure) {
    // On phones the dashboard folds the activity feed into itself. The bottom
    // bar carries five panes; Funds opens the war chest, emergency funds,
    // vacations and homestead, and Goals links the trophy hall.
    const tabs = kNarrowPanes;
    final index = tabs.contains(_pane) ? tabs.indexOf(_pane) : 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(adventure)),
        actions: [
          ..._hallAction(),
          const SpoilsEntryButton(),
          _manageAction(context),
          const PlayModeMenuButton(),
        ],
      ),
      body: _paneBody(_pane, showActivity: true),
      floatingActionButton: _fab(context),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => _select(tabs[i]),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Ledger',
          ),
          const NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag),
            label: 'Goals',
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_outlined),
            selectedIcon: const Icon(Icons.account_balance),
            label: _fundsLabel(adventure),
          ),
          const NavigationDestination(
            icon: Icon(Icons.forum_outlined),
            selectedIcon: Icon(Icons.forum),
            label: 'Activity',
          ),
        ],
      ),
    );
  }

  // ---- Wide: navigation rail, two panes (pane | activity) ---------------
  Widget _buildWide(BuildContext context, bool adventure) {
    // The rail switches the left pane; activity is pinned on the right.
    const leftPanes = kWidePanes;
    final railIndex = leftPanes.contains(_pane) ? leftPanes.indexOf(_pane) : 0;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(adventure)),
        actions: [
          ..._hallAction(),
          const SpoilsEntryButton(),
          _manageAction(context),
          const PlayModeMenuButton(),
        ],
      ),
      floatingActionButton: _fab(context),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: railIndex,
            onDestinationSelected: (i) => _select(leftPanes[i]),
            labelType: NavigationRailLabelType.all,
            destinations: [
              const NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Ledger'),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.flag_outlined),
                selectedIcon: Icon(Icons.flag),
                label: Text('Goals'),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.account_balance_outlined),
                selectedIcon: const Icon(Icons.account_balance),
                label: Text(_fundsLabel(adventure)),
              ),
              const NavigationRailDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: Text('Trophies'),
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
          const SizedBox(width: 360, child: ActivityScreen()),
        ],
      ),
    );
  }

  /// The Manage menu: setup, sync, the change log and settings.
  Widget _manageAction(BuildContext context) => IconButton(
    tooltip: 'Manage',
    icon: const Icon(Icons.menu),
    onPressed: () => ManageScreen.open(context),
  );

  /// The guild-hall entry point, present only in Adventure mode.
  List<Widget> _hallAction() => [
    if (widget.onOpenHall != null)
      IconButton(
        tooltip: 'Guild hall',
        icon: const Icon(Icons.castle_outlined),
        onPressed: widget.onOpenHall,
      ),
  ];

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
      userNames: {
        for (final member in state.members.values) member.memberId: member.name,
      },
    );
    await ref
        .read(sheetsSyncServiceProvider)
        .maybePushAfterSync(
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
