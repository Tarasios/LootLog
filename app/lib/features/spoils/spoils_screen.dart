/// Screen glue for the spoils ritual: opens the resumable sheet from the
/// dashboard and turns the user's confirmed [SpoilsResult] into appended events
/// (one [VariableExpenseRecorded] per tally, one [LeftoverAllocated] per slice).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../game/adventure_screen.dart' show customSpriteBlobsProvider;
import '../../game/adventure_spoils.dart';
import '../../game/game_sprite.dart';
import '../../game/month_end_encounters.dart';
import '../../game/skin_prefs.dart';
import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import '../report/report_screen.dart';
import 'spoils_model.dart';
import 'spoils_sheet.dart';

/// Opens the spoils ritual as a modal bottom sheet if one is pending. Safe to
/// call unconditionally; it is a no-op when nothing is actionable.
Future<void> openSpoilsRitual(BuildContext context, WidgetRef ref) async {
  final state = ref.read(householdStateProvider).value;
  final meUserId = ref.read(meUserIdProvider);
  final names = ref.read(userNamesProvider);
  final actions = ref.read(householdActionsProvider);
  if (state == null || meUserId == null || actions == null) return;

  final ritual = buildSpoilsRitual(
    state,
    meUserId: meUserId,
    userNames: names,
  );
  if (ritual == null) return;

  final adventure = ref.read(appSkinProvider) == AppSkin.adventure;
  final intro = adventure ? AdventureSpoilsRecap(ritual: ritual) : null;

  // Adventure mode replays the floor monster by monster before the division:
  // spending less than a monster's max HP is the win state, and the walkthrough
  // says so out loud. Pure display — the ritual sheet still owns every event.
  if (adventure && context.mounted) {
    final encounters = buildEncounters(state, ritual.month, meUserId);
    if (encounters.isNotEmpty) {
      final lines = await EncounterLines.load();
      final blobs = ref.read(customSpriteBlobsProvider).value ?? const {};
      if (!context.mounted) return;
      final proceed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (routeCtx) => MonthEndEncountersScreen(
            encounters: encounters,
            lines: lines,
            monthLabel: monthLabel(ritual.month.year, ritual.month.month),
            resolver: AssetSpriteResolver(customBlobs: blobs),
            onFinished: () => Navigator.of(routeCtx).pop(true),
          ),
        ),
      );
      // Backing out of the walkthrough leaves the ritual pending, untouched.
      if (proceed != true || !context.mounted) return;
    }
  }

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
          intro: intro,
          isAdventure: adventure,
          onDismiss: () => Navigator.of(context).maybePop(),
          onConfirm: (result) async {
            final navigator = Navigator.of(context);
            navigator.pop();
            await _apply(actions, ritual, result);
            // Close the floor with the month's report — the ritual summary.
            if (navigator.mounted) {
              await ReportScreen.open(navigator.context,
                  initialMonth: ritual.month);
            }
          },
        ),
      ),
    ),
  );
}

Future<void> _apply(
  HouseholdActions actions,
  SpoilsRitual ritual,
  SpoilsResult result,
) async {
  for (final t in result.tallies) {
    await actions.recordVariableActual(
      expenseId: t.expenseId,
      month: ritual.month,
      actualCents: t.actualCents,
    );
  }
  for (final a in result.allocations) {
    await actions.allocateLeftover(
      forUserId: ritual.forUserId,
      month: ritual.month,
      sliceId: a.sliceId,
      allocations: a.allocations,
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
    final ritual =
        buildSpoilsRitual(state, meUserId: meUserId, userNames: names);
    if (ritual == null) return const SizedBox.shrink();
    final adventure = ref.watch(appSkinProvider) == AppSkin.adventure;
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
