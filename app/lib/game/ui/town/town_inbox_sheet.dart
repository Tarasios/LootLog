/// The Inbox bottom sheet opened from the town: the chests and rewards
/// waiting, kept live. It watches the game state, ledger view, voice and clock
/// itself (like the building sheet), so an opened chest or claimed reward
/// leaves the list at once and "Claim all" never counts stale rewards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_providers.dart';
import '../hall_common.dart';
import '../hall_home_sections.dart';
import '../hall_ledger_view.dart';
import '../hall_voice.dart';

Future<void> showTownInbox(
  BuildContext context, {
  required VoidCallback onOpenLedger,
  required HallLinks links,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (sheetContext) => HallScope(
    child: TownInboxSheet(onOpenLedger: onOpenLedger, links: links),
  ),
);

class TownInboxSheet extends ConsumerWidget {
  const TownInboxSheet({
    super.key,
    required this.onOpenLedger,
    required this.links,
  });

  final VoidCallback onOpenLedger;
  final HallLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final clock = ref.watch(gameClockProvider);
    return HallTicker(
      builder: (context) => SingleChildScrollView(
        child: InboxPanel(
          HallHomeData(
            game: game,
            view: view,
            voice: voice,
            now: clock.now(),
            onOpenLedger: onOpenLedger,
            links: links,
          ),
        ),
      ),
    );
  }
}
