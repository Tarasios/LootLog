/// The text-adventure dashboard (tier 3): the whole app rendered as styled text
/// panels — party roster, the current floor's monsters, quest bosses, the
/// treasury (gold pouch / war chest / reserve caches), the equipment-maintenance
/// report, and a scrolling adventure log in game voice.
///
/// A pure [StatelessWidget]: it renders the [GameState] + [LogEntry] list the
/// adapter produced and calls back for the few actions. It reads only the game
/// read-model and never computes a cent, so it is widget-testable without the
/// data layer.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../game_state.dart';
import 'text_widgets.dart';

/// The handful of things the text dashboard can trigger.
class TextAdventureCallbacks {
  const TextAdventureCallbacks({
    this.onStrikeMonster,
    this.onOpenSpoils,
    this.onSwitchToClassic,
    this.onSignWrit,
    this.onDeclineWrit,
  });

  /// "Strike a monster" — log a purchase (the two-tap quick entry).
  final VoidCallback? onStrikeMonster;

  /// Open the month-close battle (dividing the spoils).
  final VoidCallback? onOpenSpoils;

  /// Drop to the Classic ledger view.
  final VoidCallback? onSwitchToClassic;

  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;
}

class TextAdventureView extends StatelessWidget {
  const TextAdventureView({
    super.key,
    required this.game,
    required this.log,
    this.encouragement,
    this.spoilsPending = false,
    this.callbacks = const TextAdventureCallbacks(),
  });

  final GameState game;
  final List<LogEntry> log;

  /// A supportive line drawn from `assets/game/text/`, shown atop the log.
  final String? encouragement;

  /// Whether a month-close battle is waiting to be fought.
  final bool spoilsPending;

  final TextAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                if (spoilsPending) _spoilsCallout(context),
                for (final r in game.warChest.ransacks) _ransack(context, r),
                _roster(context),
                _floor(context),
                if (game.questMonsters.isNotEmpty) _questBosses(context),
                _treasury(context),
                if (game.warChest.writsForMe.isNotEmpty ||
                    game.warChest.writsForOther.isNotEmpty)
                  _writs(context),
                if (game.provisioning.isNotEmpty) _provisioning(context),
                _logPanel(context),
              ],
            ),
          ),
        ),
      );
    });
  }

  // ---- Header: floor, supplies, hero HP, and the two prime actions --------
  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Floor ${game.floorNumber} · '
          '${monthLabel(game.currentMonth.year, game.currentMonth.month)}',
      icon: Icons.terrain,
      trailing: TextButton.icon(
        onPressed: callbacks.onSwitchToClassic,
        icon: const Icon(Icons.list_alt, size: 16),
        label: const Text('Classic'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The party of ${game.heroName} delves on.',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Supplies this floor: ${money(game.expeditionSuppliesCents)}',
            style: monoStyle(context),
          ),
          if (game.heroWounded)
            Text(
              'The party is wounded — ${money(game.heroHpLostCents)} HP lost to '
              'enraged monsters.',
              style: monoStyle(context, color: scheme.error),
            )
          else
            Text('The party stands unhurt.',
                style: monoStyle(context, color: scheme.tertiary)),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _spoilsCallout(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The floor is cleared — divide the spoils',
      icon: Icons.auto_awesome,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Last floor is done. Fell each monster\'s leftover loot: carry it, '
            'hurl it at a quest boss, or pocket it.',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: callbacks.onOpenSpoils,
            icon: const Icon(Icons.sports_martial_arts),
            label: const Text('Enter the battle'),
          ),
        ],
      ),
    );
  }

  Widget _ransack(BuildContext context, RansackBanner r) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The war chest was ransacked!',
      icon: Icons.local_fire_department,
      accent: scheme.error,
      child: Text(
        '${money(r.excessCents)} was torn from the war chest to cover '
        '${r.cacheName} (${r.purpose}).',
        style: monoStyle(context, color: scheme.error),
      ),
    );
  }

  // ---- Party roster -------------------------------------------------------
  Widget _roster(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The Party',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (game.roster.isEmpty)
            Text('No adventurers mustered yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            for (final a in game.roster) _rosterLine(context, a),
        ],
      ),
    );
  }

  Widget _rosterLine(BuildContext context, Adventurer a) {
    final scheme = Theme.of(context).colorScheme;
    final tag = switch (a.role) {
      AdventurerRole.adventurer => 'adventurer',
      AdventurerRole.companion => 'companion',
      AdventurerRole.familiar => 'familiar',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(a.isMe ? '▶ ' : '· ',
                  style: monoStyle(context, color: scheme.primary)),
              Flexible(
                child: Text(
                  a.name,
                  style: monoStyle(context, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('($tag${a.isMe ? ', you' : ''})',
                  style: monoStyle(context, color: scheme.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              a.descriptionText?.isNotEmpty == true
                  ? a.descriptionText!
                  : 'An adventurer whose tale is yet unwritten.',
              style: monoStyle(context, color: scheme.onSurfaceVariant)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // ---- The floor: monsters + contracts + pet-linked ones ------------------
  Widget _floor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = game.monsters.isEmpty &&
        game.contracts.isEmpty &&
        game.party.every((p) => p.monsters.isEmpty && p.contracts.isEmpty);
    return TextPanel(
      title: 'The Floor',
      icon: Icons.grid_view_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (empty)
            Text('No monsters stir on this floor yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
          for (final m in game.monsters) _monsterLine(context, m),
          for (final c in game.contracts) _contractLine(context, c),
          for (final p in game.party)
            if (p.monsters.isNotEmpty || p.contracts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('${p.name}\'s charges',
                    style: monoStyle(context, color: scheme.secondary)),
              ),
              for (final m in p.monsters) _monsterLine(context, m),
              for (final c in p.contracts) _contractLine(context, c),
            ],
        ],
      ),
    );
  }

  Widget _monsterLine(BuildContext context, Monster m) {
    final scheme = Theme.of(context).colorScheme;
    final tag = m.enraged
        ? 'ENRAGED +${money(m.excessCents)}'
        : (m.defeated ? 'FELLED ✓' : (m.mine ? 'yours' : m.ownerName ?? ''));
    final tint =
        m.enraged ? scheme.error : (m.defeated ? scheme.tertiary : null);
    return _hpLine(
      context,
      name: m.name,
      bar: textBar(m.hp.fraction),
      value: '${money(m.damageCents)} / ${money(m.maxHpCents)}',
      tag: tag,
      tint: tint,
    );
  }

  Widget _contractLine(BuildContext context, PartyContract c) {
    final scheme = Theme.of(context).colorScheme;
    return _hpLine(
      context,
      name: '${c.name} (party)',
      bar: textBar(c.hp.fraction),
      value: '${money(c.damageCents)} / ${money(c.maxHpCents)}',
      tag: c.enraged ? 'ENRAGED +${money(c.excessCents)}' : 'shared',
      tint: c.enraged ? scheme.error : scheme.secondary,
    );
  }

  Widget _hpLine(
    BuildContext context, {
    required String name,
    required String bar,
    required String value,
    required String tag,
    Color? tint,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, weight: FontWeight.w600)),
              ),
              if (tag.isNotEmpty)
                Text(tag,
                    style: monoStyle(context,
                        color: tint ?? scheme.onSurfaceVariant)),
            ],
          ),
          Text('$bar  $value',
              style: monoStyle(context, color: tint ?? scheme.primary)),
        ],
      ),
    );
  }

  // ---- Quest bosses -------------------------------------------------------
  Widget _questBosses(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Quest Bosses',
      icon: Icons.flag_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final q in game.questMonsters) _questLine(context, q),
        ],
      ),
    );
  }

  Widget _questLine(BuildContext context, QuestMonster q) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(q.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, weight: FontWeight.w700)),
              ),
              Text(
                q.completed ? 'FELLED ✓' : '${q.hp.pct}%',
                style: monoStyle(context,
                    color: q.completed ? scheme.tertiary : scheme.secondary),
              ),
            ],
          ),
          Text(
            '${textBar(q.hp.fraction)}  '
            '${money(q.contributedCents)} / ${money(q.targetCents)}',
            style: monoStyle(context,
                color: q.completed ? scheme.tertiary : scheme.secondary),
          ),
          if (q.descriptionText?.isNotEmpty == true)
            Text(q.descriptionText!,
                style: monoStyle(context, color: scheme.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ---- Treasury: gold pouch, war chest, reserve caches --------------------
  Widget _treasury(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final wc = game.warChest;
    return TextPanel(
      title: 'The Treasury',
      icon: Icons.savings_outlined,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kv(context, 'Gold pouch', money(game.goldPouch.balanceCents)),
          if (game.goldPouch.projectedMintCents > 0)
            _kv(context, '  · to be minted',
                '+${money(game.goldPouch.projectedMintCents)}',
                subtle: true),
          if (game.goldPouch.clampedFlag)
            Text('  (pouch reconciled to zero)',
                style: monoStyle(context, color: scheme.error)),
          const SizedBox(height: AppSpacing.xs),
          _kv(context, 'War chest', money(wc.balanceCents)),
          if (wc.hasGoal)
            Text(
              '  ${textBar(wc.pctComplete ?? 0)}  '
              '${((wc.pctComplete ?? 0) * 100).round()}% of '
              '${money(wc.targetCents ?? 0)}'
              '${wc.monthsToGo != null ? ' · ~${wc.monthsToGo} floors' : ''}',
              style: monoStyle(context, color: scheme.tertiary),
            ),
          if (game.reserveCaches.isNotEmpty ||
              game.party.any((p) => p.reserveCaches.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Reserve caches',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
            for (final c in game.reserveCaches)
              _kv(context, '  · ${c.name}', money(c.balanceCents), subtle: true),
            for (final p in game.party)
              for (final c in p.reserveCaches)
                _kv(context, '  · ${c.name} (${p.name})',
                    money(c.balanceCents),
                    subtle: true),
          ],
        ],
      ),
    );
  }

  Widget _writs(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Writs Awaiting Signature',
      icon: Icons.draw_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in game.warChest.writsForMe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${w.byName} asks ${money(w.amountCents)} for ${w.purpose} '
                    '→ ${w.destinationLabel}',
                    style: monoStyle(context),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => callbacks.onSignWrit?.call(w.proposalId),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Sign'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            callbacks.onDeclineWrit?.call(w.proposalId),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final w in game.warChest.writsForOther)
            Text(
              'Your writ for ${money(w.amountCents)} (${w.purpose}) awaits '
              'another adventurer\'s signature.',
              style: monoStyle(context, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  // ---- Equipment maintenance & provisioning at floor start ---------------
  Widget _provisioning(BuildContext context) {
    return TextPanel(
      title: 'Equipment Maintenance & Provisioning',
      icon: Icons.build_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final p in game.provisioning) _provLine(context, p),
        ],
      ),
    );
  }

  Widget _provLine(BuildContext context, ProvisionLine p) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = <String>[
      if (p.shared) 'shared' else if (p.ownerName != null) p.ownerName!,
      if (p.awaitingTally) 'awaiting tally',
      if (p.isAnnualContract && p.daysUntilDue != null)
        dueCountdown(p.daysUntilDue!),
    ].where((s) => s.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              p.isAnnualContract ? '${p.name} (contract)' : p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: monoStyle(context),
            ),
          ),
          if (trailing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Text(trailing,
                  style: monoStyle(context, color: scheme.onSurfaceVariant)),
            ),
          Text(
            '−${money(p.amountCents)}',
            style: monoStyle(context, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ---- The adventure log --------------------------------------------------
  Widget _logPanel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Adventure Log',
      icon: Icons.menu_book_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (encouragement?.isNotEmpty == true) ...[
            Text(encouragement!,
                style: monoStyle(context, color: scheme.tertiary)
                    .copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (log.isEmpty)
            Text('The tale has not yet begun. Strike a monster to open it.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            for (final e in log) _logLine(context, e),
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
          Icon(ts.icon, size: 16, color: ts.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(e.line,
                style: monoStyle(context,
                    weight: e.tone == LogTone.ransack
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v, {bool subtle = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(k,
              style: monoStyle(context,
                  color: subtle ? scheme.onSurfaceVariant : null)),
        ),
        Text(v,
            style: monoStyle(context,
                weight: subtle ? FontWeight.w400 : FontWeight.w700,
                color: subtle ? scheme.onSurfaceVariant : null)),
      ],
    );
  }
}
