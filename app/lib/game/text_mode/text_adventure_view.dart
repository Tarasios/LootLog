/// The text-adventure dashboard (tier 3): a camp outside the dungeon, rendered
/// entirely as styled text panels — the party gathered around the campfire, the
/// current floor's monsters waiting at the dungeon entrance, the treasury
/// (gold pouch / war chest / reserve caches), the equipment-maintenance report,
/// and a scrolling adventure log in game voice. A pinned "strike a monster —
/// log a purchase" bar keeps quick entry one tap away, never scrolled off.
///
/// A pure [StatelessWidget]: it renders the [DungeonState] + [LogEntry] list the
/// adapter produced and calls back for the few actions. It reads only the game
/// read-model and never computes a cent, so it is widget-testable without the
/// data layer.
library;

import 'package:flutter/material.dart';

import '../../ui/format.dart';
import '../../ui/theme.dart';
import '../dungeon_state.dart';
import 'text_widgets.dart';

/// The handful of things the text dashboard can trigger.
class TextAdventureCallbacks {
  const TextAdventureCallbacks({
    this.onStrikeMonster,
    this.onOpenSpoils,
    this.onSwitchToClassic,
    this.onSwitchToPixels,
    this.onSignWrit,
    this.onDeclineWrit,
    this.onSealLoan,
    this.onCancelLoan,
  });

  /// "Strike a monster" — log a purchase (the two-tap quick entry).
  final VoidCallback? onStrikeMonster;

  /// Open the month-close battle (dividing the spoils).
  final VoidCallback? onOpenSpoils;

  /// Drop to the Classic ledger view.
  final VoidCallback? onSwitchToClassic;

  /// Return to the pixel presentation (tiers 1–2). Null hides the toggle, so a
  /// caller that only offers Classic keeps a single control.
  final VoidCallback? onSwitchToPixels;

  final void Function(String proposalId)? onSignWrit;
  final void Function(String proposalId)? onDeclineWrit;

  /// Seals (approves) another adventurer's guild loan.
  final void Function(String advanceId)? onSealLoan;

  /// Refuses another adventurer's guild loan, or withdraws my own.
  final void Function(String advanceId)? onCancelLoan;
}

class TextAdventureView extends StatelessWidget {
  const TextAdventureView({
    super.key,
    required this.game,
    required this.log,
    this.encouragement,
    this.campAmbience,
    this.spoilsPending = false,
    this.callbacks = const TextAdventureCallbacks(),
  });

  final DungeonState game;
  final List<LogEntry> log;

  /// A supportive line drawn from `assets/game/text/`, shown atop the log.
  final String? encouragement;

  /// A scene-setting ambience line drawn from `assets/game/text/`, spoken at
  /// the campfire. Falls back to a built-in line when the assets are unloaded.
  final String? campAmbience;

  /// Whether a month-close battle is waiting to be fought.
  final bool spoilsPending;

  final TextAdventureCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _campHeader(context),
                    if (spoilsPending) _spoilsCallout(context),
                    for (final ransack in game.warChest.ransacks)
                      _ransack(context, ransack),
                    if (game.overbudgets.isNotEmpty) _overbudgets(context),
                    _dungeonEntrance(context),
                    if (game.questMonsters.isNotEmpty) _questBosses(context),
                    _treasury(context),
                    if (game.warChest.writsForMe.isNotEmpty ||
                        game.warChest.writsForOther.isNotEmpty)
                      _writs(context),
                    if (game.warChest.loans.isNotEmpty) _loans(context),
                    if (game.provisioning.isNotEmpty) _provisioning(context),
                    _logPanel(context),
                  ],
                ),
              ),
            ),
          ),
        ),
        _strikeBar(context),
      ],
    );
  }

  // ---- The camp: the party around the fire, supplies, hero HP -------------
  Widget _campHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The Camp — outside Floor ${game.floorNumber}',
      icon: Icons.local_fire_department_outlined,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (callbacks.onSwitchToPixels != null)
            IconButton(
              onPressed: callbacks.onSwitchToPixels,
              tooltip: 'Pixel mode',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.grid_on, size: 18),
            ),
          TextButton.icon(
            onPressed: callbacks.onSwitchToClassic,
            icon: const Icon(Icons.list_alt, size: 16),
            label: const Text('Classic'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            campAmbience?.isNotEmpty == true
                ? campAmbience!
                : 'The fire crackles. '
                    '${monthLabel(game.currentMonth.year, game.currentMonth.month)}\'s '
                    'floor awaits.',
            style: monoStyle(context, color: scheme.onSurfaceVariant)
                .copyWith(fontStyle: FontStyle.italic),
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
          const SizedBox(height: AppSpacing.sm),
          Text('Around the campfire:',
              style: monoStyle(context, color: scheme.secondary)),
          if (game.roster.isEmpty)
            Text('No adventurers mustered yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            for (final adventurer in game.roster) _rosterLine(context, adventurer),
        ],
      ),
    );
  }

  // ---- The pinned prime action: quick entry, never scrolled away ----------
  Widget _strikeBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: callbacks.onStrikeMonster,
                      icon: const Icon(Icons.bolt),
                      label: const Text('Strike a monster — log a purchase'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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

  Widget _ransack(BuildContext context, RansackBanner ransack) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'The war chest was ransacked!',
      icon: Icons.local_fire_department,
      accent: scheme.error,
      child: Text(
        '${money(ransack.excessCents)} was torn from the war chest to cover '
        '${ransack.cacheName} (${ransack.purpose}).',
        style: monoStyle(context, color: scheme.error),
      ),
    );
  }

  // ---- The OVERBUDGET: outstanding debt monsters, rendered loud -----------
  Widget _overbudgets(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'THE OVERBUDGET LOOMS',
      icon: Icons.gavel_outlined,
      accent: scheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final debt in game.overbudgets) ...[
            _hpLine(
              context,
              name: 'OVERBUDGET · ${debt.categoryName}',
              bar: textBar(debt.hp.fraction),
              value: '${money(debt.paidCents)} repaid / ${money(debt.accruedCents)}',
              tag: debt.mine ? 'yours' : (debt.ownerName ?? ''),
              tint: scheme.error,
            ),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.lg),
              child: Text(
                '${debt.categoryName} is locked — its funding feeds the beast '
                'until ${money(debt.outstandingCents)} is repaid. Strike it at '
                'the spoils.',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- Party roster (rendered around the campfire) ------------------------
  Widget _rosterLine(BuildContext context, Adventurer adventurer) {
    final scheme = Theme.of(context).colorScheme;
    final tag = switch (adventurer.role) {
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
              Text(adventurer.isMe ? '▶ ' : '· ',
                  style: monoStyle(context, color: scheme.primary)),
              Flexible(
                child: Text(
                  adventurer.name,
                  style: monoStyle(context, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('($tag${adventurer.isMe ? ', you' : ''})',
                  style: monoStyle(context, color: scheme.onSurfaceVariant)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.lg),
            child: Text(
              adventurer.descriptionText?.isNotEmpty == true
                  ? adventurer.descriptionText!
                  : 'An adventurer whose tale is yet unwritten.',
              style: monoStyle(context, color: scheme.onSurfaceVariant)
                  .copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }

  // ---- The dungeon entrance: this floor's monsters + contracts ------------
  Widget _dungeonEntrance(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = game.monsters.isEmpty &&
        game.contracts.isEmpty &&
        game.party.every((partyMember) => partyMember.monsters.isEmpty && partyMember.contracts.isEmpty);
    return TextPanel(
      title: 'The Dungeon Entrance',
      icon: Icons.grid_view_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (empty)
            Text('No monsters stir on this floor yet.',
                style: monoStyle(context, color: scheme.onSurfaceVariant))
          else
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                'Floor ${game.floorNumber} gapes ahead. Within, the '
                'monsters stir:',
                style: monoStyle(context, color: scheme.onSurfaceVariant),
              ),
            ),
          for (final monster in game.monsters) _monsterLine(context, monster),
          for (final contract in game.contracts) _contractLine(context, contract),
          for (final partyMember in game.party)
            if (partyMember.monsters.isNotEmpty || partyMember.contracts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('${partyMember.name}\'s charges',
                    style: monoStyle(context, color: scheme.secondary)),
              ),
              for (final monster in partyMember.monsters) _monsterLine(context, monster),
              for (final contract in partyMember.contracts) _contractLine(context, contract),
            ],
        ],
      ),
    );
  }

  Widget _monsterLine(BuildContext context, Monster monster) {
    final scheme = Theme.of(context).colorScheme;
    final tag = monster.enraged
        ? 'ENRAGED +${money(monster.excessCents)}'
        : (monster.defeated ? 'FELLED ✓' : (monster.mine ? 'yours' : monster.ownerName ?? ''));
    final tint =
        monster.enraged ? scheme.error : (monster.defeated ? scheme.tertiary : null);
    return _hpLine(
      context,
      name: monster.name,
      bar: textBar(monster.hp.fraction),
      value: '${money(monster.damageCents)} / ${money(monster.maxHpCents)}',
      tag: tag,
      tint: tint,
    );
  }

  Widget _contractLine(BuildContext context, PartyContract contract) {
    final scheme = Theme.of(context).colorScheme;
    return _hpLine(
      context,
      name: '${contract.name} (party)',
      bar: textBar(contract.hp.fraction),
      value: '${money(contract.damageCents)} / ${money(contract.maxHpCents)}',
      tag: contract.enraged ? 'ENRAGED +${money(contract.excessCents)}' : 'shared',
      tint: contract.enraged ? scheme.error : scheme.secondary,
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
          for (final quest in game.questMonsters) _questLine(context, quest),
        ],
      ),
    );
  }

  Widget _questLine(BuildContext context, QuestMonster quest) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(quest.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(context, weight: FontWeight.w700)),
              ),
              Text(
                quest.completed ? 'FELLED ✓' : '${quest.hp.pct}%',
                style: monoStyle(context,
                    color: quest.completed ? scheme.tertiary : scheme.secondary),
              ),
            ],
          ),
          Text(
            '${textBar(quest.hp.fraction)}  '
            '${money(quest.contributedCents)} / ${money(quest.targetCents)}',
            style: monoStyle(context,
                color: quest.completed ? scheme.tertiary : scheme.secondary),
          ),
          if (quest.descriptionText?.isNotEmpty == true)
            Text(quest.descriptionText!,
                style: monoStyle(context, color: scheme.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ---- Treasury: gold pouch, war chest, reserve caches --------------------
  Widget _treasury(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final warChest = game.warChest;
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
          _kv(context, 'War chest', money(warChest.balanceCents)),
          if (warChest.hasGoal)
            Text(
              '  ${textBar(warChest.pctComplete ?? 0)}  '
              '${((warChest.pctComplete ?? 0) * 100).round()}% of '
              '${money(warChest.targetCents ?? 0)}'
              '${warChest.monthsToGo != null ? ' · ~${warChest.monthsToGo} floors' : ''}',
              style: monoStyle(context, color: scheme.tertiary),
            ),
          if (game.reserveCaches.isNotEmpty ||
              game.party.any((partyMember) => partyMember.reserveCaches.isNotEmpty)) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('Reserve caches',
                style: monoStyle(context, color: scheme.onSurfaceVariant)),
            for (final cache in game.reserveCaches)
              _kv(context, '  · ${cache.name}', money(cache.balanceCents), subtle: true),
            for (final partyMember in game.party)
              for (final cache in partyMember.reserveCaches)
                _kv(context, '  · ${cache.name} (${partyMember.name})',
                    money(cache.balanceCents),
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
          for (final writ in game.warChest.writsForMe)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${writ.byName} asks ${money(writ.amountCents)} for ${writ.purpose} '
                    '→ ${writ.destinationLabel}',
                    style: monoStyle(context),
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => callbacks.onSignWrit?.call(writ.proposalId),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Sign'),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            callbacks.onDeclineWrit?.call(writ.proposalId),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Decline'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          for (final writ in game.warChest.writsForOther)
            Text(
              'Your writ for ${money(writ.amountCents)} (${writ.purpose}) awaits '
              'another adventurer\'s signature.',
              style: monoStyle(context, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }

  Widget _loans(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    String floors(int count) => count == 1 ? 'the next floor' : 'the next $count floors';
    return TextPanel(
      title: 'Guild Loans Awaiting a Seal',
      icon: Icons.handshake_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final loan in game.warChest.loans)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loan.needsMySeal
                        ? '${loan.byName} asks a guild loan of '
                            '${money(loan.amountCents)} against the '
                            '${loan.monsterName} monster, repaid over '
                            '${floors(loan.months)}.'
                        : 'Your guild loan of ${money(loan.amountCents)} '
                            '(${loan.monsterName}, over ${floors(loan.months)}) '
                            "awaits another adventurer's seal.",
                    style: loan.needsMySeal
                        ? monoStyle(context)
                        : monoStyle(context, color: scheme.onSurfaceVariant),
                  ),
                  Row(
                    children: [
                      if (loan.needsMySeal)
                        TextButton.icon(
                          onPressed: () =>
                              callbacks.onSealLoan?.call(loan.advanceId),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Seal'),
                        ),
                      TextButton.icon(
                        onPressed: () =>
                            callbacks.onCancelLoan?.call(loan.advanceId),
                        icon: const Icon(Icons.close, size: 16),
                        label: Text(loan.needsMySeal ? 'Refuse' : 'Withdraw'),
                      ),
                    ],
                  ),
                ],
              ),
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
          for (final line in game.provisioning) _provLine(context, line),
        ],
      ),
    );
  }

  Widget _provLine(BuildContext context, ProvisionLine line) {
    final scheme = Theme.of(context).colorScheme;
    final trailing = <String>[
      if (line.shared) 'shared' else if (line.ownerName != null) line.ownerName!,
      if (line.awaitingTally) 'awaiting tally',
      if (line.isAnnualContract && line.daysUntilDue != null)
        dueCountdown(line.daysUntilDue!),
    ].where((part) => part.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              line.isAnnualContract ? '${line.name} (contract)' : line.name,
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
            '−${money(line.amountCents)}',
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
            for (final entry in log) _logLine(context, entry),
        ],
      ),
    );
  }

  Widget _logLine(BuildContext context, LogEntry entry) {
    final style = toneStyle(context, entry.tone);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, size: 16, color: style.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(entry.line,
                style: monoStyle(context,
                    weight: entry.tone == LogTone.ransack
                        ? FontWeight.w700
                        : FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value, {bool subtle = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: monoStyle(context,
                  color: subtle ? scheme.onSurfaceVariant : null)),
        ),
        Text(value,
            style: monoStyle(context,
                weight: subtle ? FontWeight.w400 : FontWeight.w700,
                color: subtle ? scheme.onSurfaceVariant : null)),
      ],
    );
  }
}
