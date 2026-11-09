/// The Inbox bottom sheet opened from the town: the chests and rewards
/// waiting, kept live, and the weekly reconcile. It watches the game state, ledger view, voice and clock
/// itself (like the building sheet), so an opened chest or claimed reward
/// leaves the list at once and "Claim all" never counts stale rewards.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../data/game_providers.dart';
import '../../domain/game_values.dart';
import '../../game_sprite.dart';
import '../habit_actions.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_home_sections.dart';
import '../hall_ledger_view.dart';
import '../hall_voice.dart';
import '../kit/kit.dart';

/// Opens the Inbox: a framed game dialog in the pixel tier, the original
/// bottom sheet in the text tier.
Future<void> showTownInbox(
  BuildContext context, {
  required VoidCallback onOpenLedger,
  required HallLinks links,
}) {
  final sheet = TownInboxSheet(onOpenLedger: onOpenLedger, links: links);
  if (!hallDeviceTextTier(context)) {
    return showGameDialog<void>(context, builder: (_) => sheet);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (sheetContext) => HallScope(child: sheet),
  );
}

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
      builder: (context) {
        final data = HallHomeData(
          game: game,
          view: view,
          voice: voice,
          now: clock.now(),
          onOpenLedger: onOpenLedger,
          links: links,
        );
        if (hallTextTier(context)) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [InboxPanel(data), _ThisWeek(data)],
            ),
          );
        }
        return GameDialog(
          title: 'Inbox',
          scene: Center(
            child: GameSprite.fromKey(GameAssetKeys.chest(ChestType.wood), label: 'Inbox', scale: 5),
          ),
          onClose: () => Navigator.of(context).pop(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InboxPanel(data, framed: true),
              _ThisWeek(data),
            ],
          ),
          actions: [
            WoodButton(
              label: 'Close',
              tone: WoodButtonTone.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// The weekly reconcile, offered where the week's rewards land.
class _ThisWeek extends StatelessWidget {
  const _ThisWeek(this.data);

  final HallHomeData data;

  @override
  Widget build(BuildContext context) => FramedSection(
    title: 'This week',
    icon: Icons.fact_check_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeeklyReconcile(
          key: const ValueKey('inbox-reconcile'),
          data: data,
          builder: (context, action) => hallTextTier(context)
              ? OutlinedButton.icon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon),
                  label: Text(action.label),
                )
              : FramedButton(
                  label: action.label,
                  secondary: true,
                  onPressed: action.onPressed,
                ),
        ),
        if (!data.view.habitsAvailable) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(kHabitsUnavailableNote, style: framedMutedStyle(context)),
        ],
      ],
    ),
  );
}
