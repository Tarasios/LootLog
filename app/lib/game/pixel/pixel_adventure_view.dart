/// The pixel-art adventure presentation (tiers 1–2): the dungeon-crawler main
/// screen. Party-member frames with HP bars flank a central floor viewport whose
/// monsters are sized by their budget; a year minimap charts the floors and a
/// scrolling adventure log runs alongside.
///
/// A pure [StatelessWidget]: it renders the [GameState] + [LogEntry] list the
/// adapter produced and calls back for the few actions, so it is golden-testable
/// at any size. Sprites resolve through the injected [SpriteResolver]:
///
///   * Tier 1 — a resolver returns art, sprites render as pixels.
///   * Tier 2 — a sprite is missing, so *that* [GameSprite] degrades to its own
///     labelled placeholder while everything around it stays art.
///
/// (Tier 3, text mode, is a separate screen reached by the global text-mode
/// toggle.) Every number here is copied from [GameState]; this file adds pixels
/// and layout, never arithmetic.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../adapter.dart' show Sprites;
import '../game_sprite.dart';
import '../game_state.dart';
import '../text_mode/text_widgets.dart' show toneStyle;

/// The actions the pixel dashboard can trigger; all optional (no-ops in goldens).
class PixelAdventureCallbacks {
  const PixelAdventureCallbacks({
    this.onStrikeMonster,
    this.onOpenSpoils,
    this.onSwitchToText,
    this.onSwitchToClassic,
    this.onSignWrit,
    this.onDeclineWrit,
  });

  /// "Strike a monster" — the two-tap quick entry (log a purchase).
  final VoidCallback? onStrikeMonster;

  /// Open the month-close battle (dividing the spoils).
  final VoidCallback? onOpenSpoils;

  /// Drop to the text-adventure tier (the global text-mode toggle).
  final VoidCallback? onSwitchToText;

  /// Drop to the Classic ledger view.
  final VoidCallback? onSwitchToClassic;

  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;
}

/// The width at or above which the screen lays out as three columns (party
/// frames · floor viewport · log); below it the same pieces stack vertically.
const double _wideBreakpoint = 760;

class PixelAdventureView extends StatelessWidget {
  const PixelAdventureView({
    super.key,
    required this.game,
    required this.log,
    this.resolver = const PlaceholderSpriteResolver(),
    this.encouragement,
    this.spoilsPending = false,
    this.animate = true,
    this.callbacks = const PixelAdventureCallbacks(),
  });

  final GameState game;
  final List<LogEntry> log;
  final SpriteResolver resolver;

  /// Whether idle sprites animate. Off makes rendering deterministic (goldens).
  final bool animate;

  /// A supportive line drawn from `assets/game/text/`, shown atop the log.
  final String? encouragement;

  /// Whether a month-close battle is waiting to be fought.
  final bool spoilsPending;

  final PixelAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= _wideBreakpoint;
      return wide ? _wide(context) : _narrow(context);
    });
  }

  // ---- Layouts ------------------------------------------------------------

  Widget _wide(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _floorBanner(context),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 240,
                  child: SingleChildScrollView(child: _partyColumn(context)),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: ListView(
                    children: [
                      if (spoilsPending) ...[
                        _spoilsCta(context),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      for (final r in game.warChest.ransacks) ...[
                        _ransack(context, r),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _floorViewport(context),
                      const SizedBox(height: AppSpacing.md),
                      _minimap(context),
                      const SizedBox(height: AppSpacing.md),
                      _treasury(context),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 280,
                  child: _logPanel(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _narrow(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _floorBanner(context),
        const SizedBox(height: AppSpacing.md),
        if (spoilsPending) ...[
          _spoilsCta(context),
          const SizedBox(height: AppSpacing.md),
        ],
        for (final r in game.warChest.ransacks) ...[
          _ransack(context, r),
          const SizedBox(height: AppSpacing.md),
        ],
        _partyStrip(context),
        const SizedBox(height: AppSpacing.md),
        _floorViewport(context),
        const SizedBox(height: AppSpacing.md),
        _minimap(context),
        const SizedBox(height: AppSpacing.md),
        _treasury(context),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 320, child: _logPanel(context)),
      ],
    );
  }

  // ---- Floor banner: floor number, supplies, hero HP, prime actions -------

  Widget _floorBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PixelPanel(
      accent: game.heroWounded ? scheme.error : scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dungeon floor ${game.floorNumber}',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      monthLabel(
                          game.currentMonth.year, game.currentMonth.month),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
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
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
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
                      ? 'The party took ${money(game.heroHpLostCents)} of '
                          'overspend damage'
                      : 'The party is hale — no monster broke through',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: game.heroWounded
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: callbacks.onStrikeMonster,
                  icon: const Icon(Icons.bolt),
                  label: const Text('Strike a monster'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: callbacks.onSwitchToText,
                tooltip: 'Text mode',
                icon: const Icon(Icons.text_fields),
              ),
              TextButton.icon(
                onPressed: callbacks.onSwitchToClassic,
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Classic'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- Party frames -------------------------------------------------------

  Widget _partyColumn(BuildContext context) {
    if (game.roster.isEmpty) {
      return _PixelPanel(
        title: 'The Party',
        child: Text(
          'No adventurers mustered yet.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    return _PixelPanel(
      title: 'The Party',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final a in game.roster)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _PartyFrame(
                adventurer: a,
                stats: _statsFor(a),
                resolver: resolver,
                animate: animate,
              ),
            ),
        ],
      ),
    );
  }

  /// The narrow-layout party: the same frames scrolling horizontally so the
  /// roster stays visible above the floor.
  Widget _partyStrip(BuildContext context) {
    if (game.roster.isEmpty) return _partyColumn(context);
    return _PixelPanel(
      title: 'The Party',
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: game.roster.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, i) {
            final a = game.roster[i];
            return SizedBox(
              width: 200,
              child: _PartyFrame(
                adventurer: a,
                stats: _statsFor(a),
                resolver: resolver,
                animate: animate,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Aggregates the monsters attributed to [a] into a health reading for the
  /// member's frame — presentation-only grouping of numbers the adapter already
  /// derived. Companions/pets with no ledger of their own read as provisioned.
  _FrameStats _statsFor(Adventurer a) {
    final monsters = <Monster>[];
    if (a.role == AdventurerRole.familiar) {
      for (final p in game.party) {
        if (p.petId == a.memberId) monsters.addAll(p.monsters);
      }
    } else {
      for (final m in game.monsters) {
        final isHers = a.isMe ? m.mine : (!m.mine && m.ownerName == a.name);
        if (isHers) monsters.add(m);
      }
    }
    var maxHp = 0;
    var damage = 0;
    var excess = 0;
    for (final m in monsters) {
      maxHp += m.maxHpCents;
      damage += m.damageCents;
      excess += m.excessCents;
    }
    return _FrameStats(
      hasLedger: monsters.isNotEmpty,
      maxHpCents: maxHp,
      damageCents: damage,
      enraged: excess > 0,
    );
  }

  // ---- Central floor viewport --------------------------------------------

  Widget _floorViewport(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final monsters = <Monster>[
      ...game.monsters,
      for (final p in game.party) ...p.monsters,
    ];
    final maxBudget = monsters.fold<int>(
        0, (m, x) => x.maxHpCents > m ? x.maxHpCents : m);
    return _PixelPanel(
      title: 'The Floor',
      accent: scheme.secondary,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 140),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: AppRadii.card,
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (monsters.isEmpty && game.questMonsters.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Center(
                  child: Text(
                    'No monsters stir on this floor yet.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
            if (monsters.isNotEmpty)
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final m in monsters)
                    _MonsterTile(
                      monster: m,
                      scale: _budgetScale(m.maxHpCents, maxBudget),
                      resolver: resolver,
                      animate: animate,
                    ),
                ],
              ),
            if (game.contracts.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final c in game.contracts) _contractRow(context, c),
            ],
            if (game.questMonsters.isNotEmpty) ...[
              const Divider(height: AppSpacing.xl),
              Text('Quest bosses',
                  style: AppText.sectionLabel(context)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  for (final q in game.questMonsters)
                    _BossTile(quest: q, resolver: resolver, animate: animate),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Maps a monster's budget (its max HP) to an integer sprite scale so bigger
  /// budgets literally loom larger on the floor. Whole-number scales only, so
  /// pixels never blur.
  int _budgetScale(int hpCents, int maxBudgetCents) {
    if (maxBudgetCents <= 0) return 2;
    final r = hpCents / maxBudgetCents;
    if (r >= 0.66) return 4;
    if (r >= 0.33) return 3;
    return 2;
  }

  Widget _contractRow(BuildContext context, PartyContract c) {
    final scheme = Theme.of(context).colorScheme;
    final color = c.enraged ? scheme.error : scheme.tertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(Icons.handshake_outlined, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${c.name} (party)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 2),
                _PixelHpBar(fraction: c.hp.fraction, color: color),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            c.enraged ? 'ENRAGED' : '${c.hp.pct}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  // ---- Year minimap -------------------------------------------------------

  Widget _minimap(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final current = game.currentMonth.month; // 1..12
    return _PixelPanel(
      title: 'Year ${game.currentMonth.year}',
      accent: scheme.tertiary,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var m = 1; m <= 12; m++)
            _MinimapTile(
              label: _monthInitials[m - 1],
              status: m < current
                  ? _FloorStatus.explored
                  : (m == current
                      ? _FloorStatus.current
                      : _FloorStatus.locked),
              wounded: m == current && game.heroWounded,
            ),
        ],
      ),
    );
  }

  // ---- Treasury: gold pouch + war chest -----------------------------------

  Widget _treasury(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wc = game.warChest;
    return _PixelPanel(
      title: 'The Treasury',
      accent: scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GameSprite(
                sprite: const SpriteRef.asset(Sprites.coin, label: 'Gold'),
                resolver: resolver,
                scale: 1,
                animate: animate,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('${game.heroName}’s gold pouch',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                money(game.goldPouch.balanceCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (game.goldPouch.projectedMintCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'This floor’s spoils would mint '
                '${money(game.goldPouch.projectedMintCents)}',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.inventory_2, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('War chest')),
              Text(
                money(wc.balanceCents),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          if (wc.hasGoal) ...[
            const SizedBox(height: AppSpacing.xs),
            _PixelHpBar(
              fraction: (wc.pctComplete ?? 0).clamp(0.0, 1.0),
              color: scheme.primary,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${((wc.pctComplete ?? 0) * 100).round()}% of '
              '${money(wc.targetCents!)}'
              '${wc.monthsToGo != null ? ' · ~${wc.monthsToGo} floors' : ''}',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
          for (final w in wc.writsForMe) ...[
            const SizedBox(height: AppSpacing.sm),
            _WritRow(writ: w, callbacks: callbacks),
          ],
          for (final w in wc.writsForOther) ...[
            const SizedBox(height: AppSpacing.sm),
            _WritRow(writ: w, callbacks: callbacks),
          ],
        ],
      ),
    );
  }

  // ---- Scrolling adventure log --------------------------------------------

  Widget _logPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _PixelPanel(
      title: 'Adventure Log',
      accent: scheme.secondary,
      fill: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (encouragement?.isNotEmpty == true) ...[
            Text(
              encouragement!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Expanded(
            child: log.isEmpty
                ? Text(
                    'The tale has not yet begun. Strike a monster to open it.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: log.length,
                    itemBuilder: (context, i) => _logLine(context, log[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _logLine(BuildContext context, LogEntry e) {
    final ts = toneStyle(context, e.tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ts.icon, size: 14, color: ts.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              e.line,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: e.tone == LogTone.ransack
                        ? FontWeight.w800
                        : FontWeight.w400,
                    color: e.tone == LogTone.ransack ? ts.color : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Callouts -----------------------------------------------------------

  Widget _spoilsCta(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: AppRadii.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: callbacks.onOpenSpoils,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Icon(Icons.military_tech, color: scheme.onTertiaryContainer),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'The floor is cleared — divide the spoils',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ransack(BuildContext context, RansackBanner r) {
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
                  '${money(r.excessCents)} raided for ${r.cacheName}'
                  '${r.purpose.isEmpty ? '' : ' · ${r.purpose}'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onErrorContainer),
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
// Per-member health reading for a party frame.
// ===========================================================================

class _FrameStats {
  const _FrameStats({
    required this.hasLedger,
    required this.maxHpCents,
    required this.damageCents,
    required this.enraged,
  });

  /// Whether this member owns any monsters (adults do; companions/pets may not).
  final bool hasLedger;
  final int maxHpCents;
  final int damageCents;
  final bool enraged;

  /// Remaining-health fraction (full when the member carries no ledger).
  double get fraction {
    if (!hasLedger || maxHpCents <= 0) return 1;
    final remaining = maxHpCents - damageCents;
    final f = remaining / maxHpCents;
    return f < 0 ? 0 : (f > 1 ? 1 : f);
  }
}

// ===========================================================================
// Party frame: a portrait, name, role and an HP bar.
// ===========================================================================

class _PartyFrame extends StatelessWidget {
  const _PartyFrame({
    required this.adventurer,
    required this.stats,
    required this.resolver,
    required this.animate,
  });

  final Adventurer adventurer;
  final _FrameStats stats;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = adventurer.isMe ? scheme.primary : scheme.outlineVariant;
    final barColor = stats.enraged ? scheme.error : scheme.primary;
    final role = switch (adventurer.role) {
      AdventurerRole.adventurer => 'adventurer',
      AdventurerRole.companion => 'companion',
      AdventurerRole.familiar => 'familiar',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: Border.all(
          color: tint,
          width: adventurer.isMe ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          GameSprite(
            sprite: adventurer.sprite,
            resolver: resolver,
            baseSize: kPortraitBaseSize,
            scale: 1,
            animate: animate,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        adventurer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (adventurer.isMe)
                      Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.xxs),
                        child: Text('(you)',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: scheme.primary)),
                      ),
                  ],
                ),
                Text(role,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xxs),
                if (stats.hasLedger)
                  _PixelHpBar(fraction: stats.fraction, color: barColor)
                else
                  Text('provisioned',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: scheme.tertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Monster tile: a sprite sized by budget, its name and a small HP bar.
// ===========================================================================

class _MonsterTile extends StatelessWidget {
  const _MonsterTile({
    required this.monster,
    required this.scale,
    required this.resolver,
    required this.animate,
  });

  final Monster monster;
  final int scale;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = monster.enraged
        ? scheme.error
        : (monster.mine ? scheme.primary : scheme.secondary);
    return SizedBox(
      width: (kSpriteBaseSize * 4) + AppSpacing.sm * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: monster.enraged
                ? BoxDecoration(
                    borderRadius: AppRadii.chip,
                    border: Border.all(color: scheme.error, width: 1.5),
                  )
                : null,
            child: GameSprite(
              sprite: monster.sprite,
              resolver: resolver,
              scale: scale,
              animate: animate,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            monster.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          _PixelHpBar(fraction: monster.hp.fraction, color: color),
          Text(
            monster.enraged
                ? '+${money(monster.excessCents)} broke through'
                : '${monster.hp.pct}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: monster.enraged ? scheme.error : scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Boss tile: a quest boss sprite with its progress toward completion.
// ===========================================================================

class _BossTile extends StatelessWidget {
  const _BossTile({
    required this.quest,
    required this.resolver,
    required this.animate,
  });

  final QuestMonster quest;
  final SpriteResolver resolver;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = quest.completed ? scheme.primary : scheme.secondary;
    return SizedBox(
      width: (kSpriteBaseSize * 4) + AppSpacing.sm * 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.topRight,
            children: [
              GameSprite(
                sprite: quest.sprite,
                resolver: resolver,
                scale: 4,
                animate: animate && !quest.completed,
              ),
              if (quest.completed)
                GameSprite(
                  sprite: const SpriteRef.asset(Sprites.trophy, label: 'Trophy'),
                  resolver: resolver,
                  scale: 1,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            quest.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          _PixelHpBar(fraction: quest.hp.fraction, color: color),
          Text(
            quest.completed ? 'FELLED ✓' : '${quest.hp.pct}%',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Year minimap tile.
// ===========================================================================

enum _FloorStatus { explored, current, locked }

const List<String> _monthInitials = [
  'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D',
];

class _MinimapTile extends StatelessWidget {
  const _MinimapTile({
    required this.label,
    required this.status,
    required this.wounded,
  });

  final String label;
  final _FloorStatus status;
  final bool wounded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (status) {
      _FloorStatus.current => wounded
          ? (scheme.error, scheme.onError, scheme.error)
          : (scheme.primary, scheme.onPrimary, scheme.primary),
      _FloorStatus.explored => (
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
          scheme.secondary,
        ),
      _FloorStatus.locked => (
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
          scheme.outlineVariant,
        ),
    };
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: status == _FloorStatus.current
              ? FontWeight.w900
              : FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ===========================================================================
// Writ row (withdrawal awaiting a signature).
// ===========================================================================

class _WritRow extends StatelessWidget {
  const _WritRow({required this.writ, required this.callbacks});

  final Writ writ;
  final PixelAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = writ.needsMySignature;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: AppRadii.card,
        border: mine ? Border.all(color: scheme.primary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_edu, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  mine
                      ? 'A writ awaits your signature'
                      : 'A writ awaits another adventurer',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(writ.amountCents),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
          Text(
            '${writ.byName} · ${writ.purpose} → ${writ.destinationLabel}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (mine)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: callbacks.onDeclineWrit == null
                      ? null
                      : () => callbacks.onDeclineWrit!(writ.proposalId),
                  child: const Text('Refuse'),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: callbacks.onSignWrit == null
                      ? null
                      : () => callbacks.onSignWrit!(writ.proposalId),
                  // The app themes filled buttons full-width; constrain it so it
                  // sits inline in this action row.
                  style:
                      FilledButton.styleFrom(minimumSize: const Size(72, 40)),
                  child: const Text('Sign'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared pixel chrome.
// ===========================================================================

/// A blocky, segmented HP/progress bar — the pixel tier's take on the text-mode
/// block bar. [fraction] is clamped to 0..1.
class _PixelHpBar extends StatelessWidget {
  const _PixelHpBar({
    required this.fraction,
    required this.color,
  });

  final double fraction;
  final Color color;

  /// Number of blocky cells in the bar.
  static const int cells = 10;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    final filled = (f * cells).round();
    return Row(
      children: [
        for (var i = 0; i < cells; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i == cells - 1 ? 0 : 1),
              color: i < filled ? color : scheme.surfaceContainerLow,
            ),
          ),
      ],
    );
  }
}

/// A titled panel — the pixel tier's recurring frame. Where a 9-slice panel PNG
/// would sit (see `docs/art-assets.md`), a themed rounded box stands in, so a
/// missing panel asset is graceful, never a gap.
class _PixelPanel extends StatelessWidget {
  const _PixelPanel({
    required this.child,
    this.title,
    this.accent,
    this.fill = false,
  });

  final Widget child;
  final String? title;
  final Color? accent;

  /// When true the child is given the panel's full height (for the log's
  /// internal scroll view).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    final body = Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: child,
    );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadii.card,
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: tint, width: 3)),
              ),
              child: Text(
                title!.toUpperCase(),
                style: AppText.sectionLabel(context)
                    .copyWith(color: tint, letterSpacing: 1),
              ),
            ),
          fill ? Expanded(child: body) : body,
        ],
      ),
    );
  }
}

// ===========================================================================
// Small shared pill.
// ===========================================================================

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
