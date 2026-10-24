/// Screen glue for the spoils ritual: opens the resumable sheet from the
/// dashboard and turns the user's confirmed [SpoilsResult] into appended events
/// (one [VariableExpenseRecorded] per tally, one [LeftoverAllocated] per slice).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../game/ui/dungeon/dungeon_screen.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import '../report/report_screen.dart';
import '../settings/play_mode_providers.dart';
import 'spoils_model.dart';
import 'spoils_sheet.dart';

/// Opens the month-end ritual if one is pending. In Adventure mode that is
/// the month-end dungeon below the town gate (which also brings home the
/// spoils chest when nothing is left to divide); in Standard mode it is the
/// plain resumable sheet. Safe to call unconditionally: the sheet is a no-op
/// when nothing is actionable. [asOf] defaults to now.
Future<void> openSpoilsRitual(
  BuildContext context,
  WidgetRef ref, {
  DateTime? asOf,
}) async {
  if (ref.read(isAdventureProvider)) {
    await DungeonScreen.open(context);
    return;
  }
  final state = ref.read(householdStateProvider).value;
  final meUserId = ref.read(meUserIdProvider);
  final names = ref.read(userNamesProvider);
  final actions = ref.read(householdActionsProvider);
  if (state == null || meUserId == null || actions == null) return;

  final ritual = buildSpoilsRitual(
    state,
    meUserId: meUserId,
    userNames: names,
    asOf: asOf,
  );
  if (ritual == null || !context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: SpoilsSheetView(
          ritual: ritual,
          onDismiss: () => Navigator.of(context).maybePop(),
          onConfirm: (result) async {
            final navigator = Navigator.of(context);
            navigator.pop();
            await applySpoilsResult(actions, ritual, result);
            // Close the floor with the month's report — the ritual summary.
            if (navigator.mounted) {
              await ReportScreen.open(
                navigator.context,
                initialMonth: ritual.month,
              );
            }
          },
        ),
      ),
    ),
  );
}

/// Writes a confirmed ritual: variable actuals first, then one allocation per
/// category. The one path every month-end surface uses.
Future<void> applySpoilsResult(
  HouseholdActions actions,
  SpoilsRitual ritual,
  SpoilsResult result,
) async {
  for (final tally in result.tallies) {
    await actions.recordVariableActual(
      expenseId: tally.expenseId,
      month: ritual.month,
      actualCents: tally.actualCents,
    );
  }
  for (final allocation in result.allocations) {
    await actions.allocateLeftover(
      forUserId: ritual.forUserId,
      month: ritual.month,
      sliceId: allocation.sliceId,
      allocations: allocation.allocations,
    );
  }
}

/// A dashboard affordance: shows the ritual button only while one is pending.
class SpoilsEntryButton extends ConsumerWidget {
  const SpoilsEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    if (state == null || meUserId == null) return const SizedBox.shrink();
    final ritual = buildSpoilsRitual(
      state,
      meUserId: meUserId,
      userNames: names,
    );
    if (ritual == null) return const SizedBox.shrink();
    final adventure = ref.watch(isAdventureProvider);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilledButton.tonalIcon(
        onPressed: () => unawaited(openSpoilsRitual(context, ref)),
        icon: const Icon(Icons.auto_awesome, size: 18),
        label: Text(adventure ? 'Divide the spoils' : 'Divide leftovers'),
      ),
    );
  }
}
