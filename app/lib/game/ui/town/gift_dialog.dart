/// The gift dialog: the materials you hold, each with a stepper (never past
/// what you hold or what the neighbour's storehouse has room for), a line
/// saying how much their storehouse holds, and Send, which runs `sendGift`
/// once and says what actually moved. A framed game dialog in the pixel
/// tier, a bottom sheet in the text tier.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../ui/theme.dart';
import '../../assets/asset_catalog.dart';
import '../../assets/asset_key.dart';
import '../../assets/pack_sprite.dart';
import '../../config/balance.dart';
import '../../data/game_providers.dart';
import '../../domain/game_event.dart';
import '../../domain/game_values.dart';
import '../../domain/town/neighbour_lines.dart';
import '../../domain/town/neighbours.dart';
import '../../game_sprite.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../hall_names.dart';
import '../kit/kit.dart';
import 'neighbour_providers.dart';

/// Opens the gift dialog for [neighbour].
Future<void> showGiftDialog(BuildContext context, TownNeighbour neighbour) {
  final dialog = GiftDialog(neighbour: neighbour);
  if (!hallDeviceTextTier(context)) {
    return showGameDialog<void>(context, builder: (_) => dialog);
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => HallScope(child: SingleChildScrollView(child: dialog)),
  );
}

class GiftDialog extends ConsumerStatefulWidget {
  const GiftDialog({super.key, required this.neighbour});

  final TownNeighbour neighbour;

  @override
  ConsumerState<GiftDialog> createState() => _GiftDialogState();
}

class _GiftDialogState extends ConsumerState<GiftDialog> {
  final Map<MaterialKind, int> _chosen = {};
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId ?? '';
    final now = ref.watch(gameClockProvider).now();
    final lines = ref.watch(neighbourLinesProvider).value ?? NeighbourLines.defaults;
    final neighbour = widget.neighbour;
    final held = game.townOf(meId).materials;
    final kinds = [
      for (final kind in MaterialKind.values)
        if (held[kind] > 0) kind,
    ];
    // Clamp the choice against what is live now: another device may have
    // spent the materials or filled the neighbour's storehouse meanwhile,
    // and a row that disappears must not still be sent.
    final limits = {
      for (final kind in kinds) kind: _min(held[kind], giftRoom(game, neighbour.memberId, kind, now)),
    };
    _chosen
      ..removeWhere((kind, _) => !limits.containsKey(kind))
      ..updateAll((kind, amount) => amount.clamp(0, limits[kind]!));
    final name = {'name': neighbour.name};
    final rows = <Widget>[
      Text(lines.line('gift.intro', name), style: framedBodyStyle(context)),
      const SizedBox(height: AdventureTokens.gap),
      Text(
        lines.line('gift.room', {
          ...name,
          'capacity': '${game.townOf(neighbour.memberId).storageCapacityAt(now)}',
        }),
        style: framedMutedStyle(context),
      ),
      const SizedBox(height: AdventureTokens.gap),
      if (kinds.isEmpty) Text(lines.line('gift.nothing'), style: framedBodyStyle(context)),
      for (final kind in kinds)
        _stepperRow(context, kind,
            held: held[kind], room: giftRoom(game, neighbour.memberId, kind, now), most: limits[kind]!),
    ];
    final anyChosen = _chosen.values.any((amount) => amount > 0);
    final send = WoodButton(
      key: const ValueKey('gift-send'),
      label: 'Send',
      icon: Icons.card_giftcard,
      onPressed: anyChosen && !_sending ? () => _send(lines) : null,
    );
    final close = WoodButton(
      label: 'Close',
      tone: WoodButtonTone.secondary,
      onPressed: () => Navigator.of(context).pop(),
    );
    if (hallTextTier(context)) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lines.line('gift.title', name), style: framedBodyStyle(context, weight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            ...rows,
            const SizedBox(height: AppSpacing.sm),
            Wrap(spacing: AppSpacing.sm, children: [send, close]),
          ],
        ),
      );
    }
    return GameDialog(
      title: lines.line('gift.title', name),
      // The trade road's wagon carries the gift.
      scene: const Center(child: PackSprite(assetKey: AssetKey('town', 'wagon'), scale: 4)),
      onClose: () => Navigator.of(context).pop(),
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows),
      actions: [close, send],
    );
  }

  /// One material: its picture and name, what you hold and the room left,
  /// and a stepper bounded by both.
  Widget _stepperRow(
    BuildContext context,
    MaterialKind kind, {
    required int held,
    required int room,
    required int most,
  }) {
    final amount = _chosen[kind] ?? 0;
    void change(int delta) => setState(() => _chosen[kind] = (amount + delta).clamp(0, most));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          GameSprite.fromKey(GameAssetKeys.material(kind), label: HallNames.material(kind), scale: 2),
          const SizedBox(width: AdventureTokens.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(HallNames.material(kind), style: framedBodyStyle(context, weight: FontWeight.w700)),
                Text(
                  '$held held · room for $room',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: framedMutedStyle(context),
                ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('gift-less-${kind.name}'),
            tooltip: 'Less',
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: amount > 0 ? () => change(-Balance.giftStepAmount) : null,
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$amount',
              key: ValueKey('gift-amount-${kind.name}'),
              textAlign: TextAlign.center,
              style: AdventureTokens.amount(context),
            ),
          ),
          IconButton(
            key: ValueKey('gift-more-${kind.name}'),
            tooltip: 'More',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: amount < most ? () => change(Balance.giftStepAmount) : null,
          ),
        ],
      ),
    );
  }

  /// Runs `sendGift` once with the chosen bundle, then says what moved.
  Future<void> _send(NeighbourLines lines) async {
    final neighbour = widget.neighbour;
    final chosen = MaterialBundle({
      for (final entry in _chosen.entries)
        if (entry.value > 0) entry.key: entry.value,
    });
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final result = await runHallCommand(context, ref, (service) => service.sendGift(neighbour.memberId, chosen));
    if (!mounted) return;
    setState(() => _sending = false);
    if (result == null || !result.accepted) return;
    final moved = result.events.whereType<GiftSent>().firstOrNull?.bundle ?? chosen;
    final fill = {'name': neighbour.name, 'goods': HallNames.bundle(moved)};
    navigator.pop();
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(lines.line(moved == chosen ? 'gift.sent' : 'gift.trimmed', fill))));
  }
}

int _min(int first, int second) => first < second ? first : second;
