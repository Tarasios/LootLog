/// The adventure dashboard: a pure widget that renders a [DungeonState] as a
/// dungeon floor. It owns no state and reads no providers, so it is
/// golden-testable at any size. Sprites resolve through the injected
/// [SpriteResolver]; goldens pass a placeholder-only resolver so nothing decodes
/// asynchronously.
///
/// Every number here is copied from [DungeonState] (which came straight from the
/// reducer). This file adds vocabulary and pixels, never arithmetic.
///
/// This file holds the dashboard layout and its callbacks; each card (with its
/// private pieces) is a part file under `adventure_dashboard/`.
library;

import 'package:flutter/material.dart';

import '../ui/format.dart';
import '../ui/theme.dart';
import 'game_sprite.dart';
import 'dungeon_state.dart';

part 'adventure_dashboard/contract_banner.dart';
part 'adventure_dashboard/expedition_card.dart';
part 'adventure_dashboard/floor_header.dart';
part 'adventure_dashboard/gold_pouch_card.dart';
part 'adventure_dashboard/monster_card.dart';
part 'adventure_dashboard/party_member_card.dart';
part 'adventure_dashboard/provisioning_ledger.dart';
part 'adventure_dashboard/quest_monster_card.dart';
part 'adventure_dashboard/shared_pieces.dart';
part 'adventure_dashboard/spoils_banner.dart';
part 'adventure_dashboard/war_chest_card.dart';

/// Callbacks the adventure dashboard needs; defaulted to no-ops for goldens.
class AdventureCallbacks {
  const AdventureCallbacks({
    this.onOpenSpoils,
    this.onSignWrit,
    this.onDeclineWrit,
  });

  final VoidCallback? onOpenSpoils;
  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;
}

class AdventureDashboard extends StatelessWidget {
  const AdventureDashboard({
    super.key,
    required this.game,
    this.resolver = const PlaceholderSpriteResolver(),
    this.spoilsBanner,
    this.callbacks = const AdventureCallbacks(),
  });

  final DungeonState game;
  final SpriteResolver resolver;

  /// An optional "divide the spoils" call-to-action, when a ritual is pending.
  final AdventureSpoilsBanner? spoilsBanner;
  final AdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        _FloorHeader(game: game, resolver: resolver),
        if (spoilsBanner != null) ...[
          const SizedBox(height: AppSpacing.md),
          _SpoilsCta(banner: spoilsBanner!, onOpen: callbacks.onOpenSpoils),
        ],
        if (game.monsters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Monsters on this floor',
            child: Column(
              children: [
                for (final monster in game.monsters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: MonsterCard(monster: monster, resolver: resolver),
                  ),
              ],
            ),
          ),
        ],
        if (game.contracts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Party contracts',
            child: Column(
              children: [
                for (final contract in game.contracts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ContractBanner(contract: contract),
                  ),
              ],
            ),
          ),
        ],
        for (final member in game.party) ...[
          const SizedBox(height: AppSpacing.md),
          PartyMemberCard(member: member, resolver: resolver),
        ],
        if (game.questMonsters.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Quest monsters',
            child: Column(
              children: [
                for (final quest in game.questMonsters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: QuestMonsterCard(quest: quest, resolver: resolver),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        GoldPouchCard(pouch: game.goldPouch, heroName: game.heroName),
        const SizedBox(height: AppSpacing.md),
        WarChestCard(chest: game.warChest, callbacks: callbacks),
        if (game.provisioning.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ProvisioningLedger(lines: game.provisioning),
        ],
        if (game.reserveCaches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          ReserveCacheStrip(caches: game.reserveCaches),
        ],
        for (final expedition in game.expeditions) ...[
          const SizedBox(height: AppSpacing.md),
          ExpeditionFloorCard(expedition: expedition),
        ],
      ],
    );
  }
}

