/// The adventure dashboard: a pure widget that renders a [GameState] as a
/// dungeon floor. It owns no state and reads no providers, so it is
/// golden-testable at any size. Sprites resolve through the injected
/// [SpriteResolver]; goldens pass a placeholder-only resolver so nothing decodes
/// asynchronously.
///
/// Every number here is copied from [GameState] (which came straight from the
/// reducer). This file adds vocabulary and pixels, never arithmetic.
library;

import 'package:flutter/material.dart';

import '../ui/format.dart';
import '../ui/theme.dart';
import 'game_sprite.dart';
import 'game_state.dart';

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

  final GameState game;
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
                for (final m in game.monsters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: MonsterCard(monster: m, resolver: resolver),
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
                for (final c in game.contracts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ContractBanner(contract: c),
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
                for (final q in game.questMonsters)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: QuestMonsterCard(quest: q, resolver: resolver),
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
      ],
    );
  }
}

// ===========================================================================
// Floor header: dungeon floor + both idle avatars + hero HP.
// ===========================================================================

class _FloorHeader extends StatelessWidget {
  const _FloorHeader({required this.game, required this.resolver});

  final GameState game;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        gradient: LinearGradient(
          colors: [scheme.surfaceContainerHigh, scheme.surfaceContainerLow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: game.heroSprite,
                resolver: resolver,
                scale: 2,
                animate: true,
              ),
              const SizedBox(width: AppSpacing.xs),
              GameSprite(
                sprite: game.partnerSprite,
                resolver: resolver,
                scale: 2,
                animate: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dungeon floor ${game.floorNumber}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      monthLabel(
                        game.currentMonth.year,
                        game.currentMonth.month,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _HeroStatus(game: game),
        ],
      ),
    );
  }
}

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.game});

  final GameState game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          game.heroWounded ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: game.heroWounded ? scheme.error : scheme.primary,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            game.heroWounded
                ? '${game.heroName} took ${money(game.heroHpLostCents)} of '
                    'overspend damage'
                : '${game.heroName} is hale — no monster broke through',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: game.heroWounded
                      ? scheme.error
                      : scheme.onSurfaceVariant,
                ),
          ),
        ),
        if (game.expeditionSuppliesCents > 0)
          _Pill(
            icon: Icons.inventory_2_outlined,
            label: '${money(game.expeditionSuppliesCents)} supplies',
            color: scheme.tertiaryContainer,
            onColor: scheme.onTertiaryContainer,
          ),
      ],
    );
  }
}

// ===========================================================================
// Monster card (personal slice).
// ===========================================================================

/// A personal-slice monster with an HP bar and an optional hit-flash overlay.
class MonsterCard extends StatelessWidget {
  const MonsterCard({
    super.key,
    required this.monster,
    this.resolver = const PlaceholderSpriteResolver(),
    this.flash = false,
  });

  final Monster monster;
  final SpriteResolver resolver;

  /// Momentary "just took damage" tint (driven by the screen on a new hit).
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barColor = monster.enraged
        ? scheme.error
        : (monster.mine ? scheme.primary : scheme.secondary);
    return AnimatedContainer(
      duration: AppDurations.fast,
      decoration: BoxDecoration(
        color: flash
            ? scheme.error.withValues(alpha: 0.18)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: monster.enraged
            ? Border.all(color: scheme.error, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          GameSprite(
            sprite: monster.sprite,
            resolver: resolver,
            scale: 3,
            animate: true,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        monster.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (monster.enraged)
                      _Tag(label: 'ENRAGED', color: scheme.error)
                    else if (monster.defeated)
                      _Tag(label: 'DEFEATED', color: scheme.primary)
                    else if (!monster.mine && monster.ownerName != null)
                      Text(
                        monster.ownerName!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _HpBarView(
                  bar: monster.hp,
                  color: barColor,
                  trackColor: scheme.surfaceContainerLow,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  monster.enraged
                      ? '${money(monster.damageCents)} dealt · '
                          '${money(monster.excessCents)} broke through'
                      : '${money(monster.damageCents)} / '
                          '${money(monster.maxHpCents)} HP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Party contract (group slice) with a dual-colour banner.
// ===========================================================================

class ContractBanner extends StatelessWidget {
  const ContractBanner({super.key, required this.contract});

  final PartyContract contract;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final left = contract.enraged ? scheme.error : scheme.primary;
    final right = contract.enraged ? scheme.error : scheme.tertiary;
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            height: 6,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [left, right]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.handshake_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        contract.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (contract.petName != null)
                      _Tag(label: contract.petName!, color: scheme.tertiary),
                    if (contract.enraged)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: _Tag(label: 'ENRAGED', color: scheme.error),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _HpBarView(
                  bar: contract.hp,
                  color: contract.enraged ? scheme.error : scheme.tertiary,
                  trackColor: scheme.surfaceContainerHighest,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${money(contract.damageCents)} / '
                  '${money(contract.maxHpCents)} shared HP',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Party member (pet) owning its monsters, contracts, and reserve caches.
// ===========================================================================

class PartyMemberCard extends StatelessWidget {
  const PartyMemberCard({
    super.key,
    required this.member,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final PartyMember member;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: member.sprite,
                resolver: resolver,
                scale: 3,
                animate: true,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Party member',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final m in member.monsters) ...[
            const SizedBox(height: AppSpacing.sm),
            MonsterCard(monster: m, resolver: resolver),
          ],
          for (final c in member.contracts) ...[
            const SizedBox(height: AppSpacing.sm),
            ContractBanner(contract: c),
          ],
          if (member.reserveCaches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final cache in member.reserveCaches)
                  _CacheChip(cache: cache),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Quest monster.
// ===========================================================================

class QuestMonsterCard extends StatelessWidget {
  const QuestMonsterCard({
    super.key,
    required this.quest,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final QuestMonster quest;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GameSprite(
          sprite: quest.sprite,
          resolver: resolver,
          scale: 3,
          animate: !quest.completed,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      quest.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (quest.shared)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: _Tag(label: 'Shared', color: scheme.tertiary),
                    ),
                  if (quest.completed)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(Icons.emoji_events,
                          size: 16, color: scheme.primary),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              _HpBarView(
                bar: quest.hp,
                color: quest.completed ? scheme.primary : scheme.tertiary,
                trackColor: scheme.surfaceContainerHighest,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${money(quest.contributedCents)} / '
                '${money(quest.targetCents)} HP'
                '${quest.completed ? ' · trophy claimed' : ''}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              if (quest.shared && quest.contributors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    quest.contributors
                        .map((c) => '${c.name} ${money(c.cents)}')
                        .join('  ·  '),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// Gold pouch (vault).
// ===========================================================================

class GoldPouchCard extends StatelessWidget {
  const GoldPouchCard({
    super.key,
    required this.pouch,
    required this.heroName,
  });

  final GoldPouch pouch;
  final String heroName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.paid_outlined, color: scheme.onSecondaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '$heroName’s gold pouch',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                money(pouch.balanceCents),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (pouch.clampedFlag)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Pouch scraped empty — check recent charges',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ),
          if (pouch.projectedMintCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'This floor’s spoils would mint '
                '${money(pouch.projectedMintCents)} into the pouch',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// War chest (pool) with writs + ransack banners.
// ===========================================================================

class WarChestCard extends StatelessWidget {
  const WarChestCard({
    super.key,
    required this.chest,
    this.callbacks = const AdventureCallbacks(),
  });

  final WarChest chest;
  final AdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'War chest',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(chest.balanceCents),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (chest.hasGoal) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (chest.pctComplete ?? 0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              [
                '${((chest.pctComplete ?? 0) * 100).round()}% of ${money(chest.targetCents!)}',
                if (chest.monthsToGo != null)
                  'about ${chest.monthsToGo} floor${chest.monthsToGo == 1 ? '' : 's'} to go',
              ].join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final r in chest.ransacks) ...[
            const SizedBox(height: AppSpacing.md),
            RansackBannerView(banner: r),
          ],
          for (final w in chest.writsForMe) ...[
            const SizedBox(height: AppSpacing.md),
            WritTile(writ: w, callbacks: callbacks),
          ],
          for (final w in chest.writsForOther) ...[
            const SizedBox(height: AppSpacing.md),
            WritTile(writ: w, callbacks: callbacks),
          ],
        ],
      ),
    );
  }
}

class WritTile extends StatelessWidget {
  const WritTile({super.key, required this.writ, required this.callbacks});

  final Writ writ;
  final AdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = writ.needsMySignature;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: mine ? Border.all(color: scheme.primary, width: 1.5) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu,
                  size: 18,
                  color: mine ? scheme.onPrimaryContainer : scheme.onSurface),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mine
                      ? 'A writ awaits your signature'
                      : 'A writ awaits ${writ.byName == 'You' ? 'the other' : 'the other adventurer'}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: mine
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                ),
              ),
              Text(
                money(writ.amountCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color:
                          mine ? scheme.onPrimaryContainer : scheme.onSurface,
                    ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              '${writ.byName} · ${writ.purpose} → ${writ.destinationLabel}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mine
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: callbacks.onDeclineWrit == null
                        ? null
                        : () => callbacks.onDeclineWrit!(writ.proposalId),
                    child: const Text('Refuse'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    onPressed: callbacks.onSignWrit == null
                        ? null
                        : () => callbacks.onSignWrit!(writ.proposalId),
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                    child: const Text('Sign'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class RansackBannerView extends StatelessWidget {
  const RansackBannerView({super.key, required this.banner});

  final RansackBanner banner;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.error, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department,
              color: scheme.onErrorContainer, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THE WAR CHEST WAS RANSACKED',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: scheme.onErrorContainer,
                      ),
                ),
                Text(
                  '${money(banner.excessCents)} raided for '
                  '${banner.cacheName}'
                  '${banner.purpose.isEmpty ? '' : ' · ${banner.purpose}'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Provisioning ledger + reserve caches.
// ===========================================================================

class ProvisioningLedger extends StatelessWidget {
  const ProvisioningLedger({super.key, required this.lines});

  final List<ProvisionLine> lines;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Equipment maintenance & provisioning',
      child: Column(
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    switch (line.kind) {
                      ProvisionKind.emergencyProvision =>
                        Icons.shield_outlined,
                      ProvisionKind.variableMaintenance =>
                        Icons.build_circle_outlined,
                      ProvisionKind.fixedMaintenance =>
                        Icons.build_outlined,
                    },
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(line.name,
                            style: Theme.of(context).textTheme.bodyMedium),
                        Text(
                          [
                            if (line.isAnnualContract)
                              'Contract'
                            else
                              switch (line.kind) {
                                ProvisionKind.emergencyProvision => 'Provision',
                                ProvisionKind.variableMaintenance => 'Variable',
                                ProvisionKind.fixedMaintenance => 'Fixed',
                              },
                            if (line.shared)
                              'shared'
                            else if (line.ownerName != null)
                              line.ownerName!,
                            if (line.isAnnualContract)
                              recurringDueLabel(
                                isAnnual: true,
                                dueDay: line.dueDay ?? 1,
                                dueMonth: line.dueMonth,
                              ),
                          ].join(' · '),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (line.awaitingTally)
                    _Tag(
                      label: 'Awaiting tally',
                      color: scheme.tertiary,
                    )
                  else if (line.isAnnualContract)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${money(line.amountCents)}/floor',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures()
                                    ],
                                  ),
                        ),
                        _Tag(
                          label: dueCountdown(line.daysUntilDue ?? 0),
                          color: (line.daysUntilDue ?? 99) <= 7
                              ? scheme.tertiary
                              : scheme.primary,
                        ),
                      ],
                    )
                  else
                    Text(
                      money(line.amountCents),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ReserveCacheStrip extends StatelessWidget {
  const ReserveCacheStrip({super.key, required this.caches});

  final List<ReserveCache> caches;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Reserve caches',
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [for (final c in caches) _CacheChip(cache: c)],
      ),
    );
  }
}

class _CacheChip extends StatelessWidget {
  const _CacheChip({required this.cache});

  final ReserveCache cache;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_moon_outlined, size: 16, color: scheme.error),
              const SizedBox(width: AppSpacing.xs),
              Text(
                cache.name,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          Text(
            money(cache.balanceCents),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
          ),
          if (cache.petName != null)
            Text(
              cache.petName!,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Spoils call-to-action banner.
// ===========================================================================

/// The data the spoils CTA renders (kept tiny; the full ritual is its own
/// screen). Sourced from the classic spoils view-model at the call site.
class AdventureSpoilsBanner {
  const AdventureSpoilsBanner({
    required this.monstersToRecap,
    required this.talliesPending,
    required this.daysRemaining,
  });

  final int monstersToRecap;
  final int talliesPending;
  final int daysRemaining;
}

class _SpoilsCta extends StatelessWidget {
  const _SpoilsCta({required this.banner, this.onOpen});

  final AdventureSpoilsBanner banner;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = <String>[
      if (banner.monstersToRecap > 0)
        '${banner.monstersToRecap} monster${banner.monstersToRecap == 1 ? '' : 's'} to loot',
      if (banner.talliesPending > 0) '${banner.talliesPending} to tally',
    ];
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.military_tech, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Divide the spoils',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      [
                        parts.join(' · '),
                        'defaults in ${banner.daysRemaining}d',
                      ].where((s) => s.isNotEmpty).join(' — '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Small shared pieces.
// ===========================================================================

class _HpBarView extends StatelessWidget {
  const _HpBarView({
    required this.bar,
    required this.color,
    required this.trackColor,
  });

  final HpBar bar;
  final Color color;
  final Color trackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: bar.fraction,
        minHeight: 8,
        backgroundColor: trackColor,
        color: color,
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(title, style: AppText.sectionLabel(context)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadii.chip,
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: AppRadii.chip),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: onColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
