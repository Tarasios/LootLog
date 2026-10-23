/// The sections of the guild-hall home: the party header, today's habits,
/// the inbox, the ritual callout, the shared stores, the plots and the places
/// to go. Each reads the projected [GameState] and the money-free
/// [HallLedgerView]; writes go through the command service or the ledger's
/// habit actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../assets/asset_key.dart';
import '../config/balance.dart';
import '../domain/game_event.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../domain/hall_rules.dart';
import '../game_sprite.dart';
import 'building_sheet.dart';
import 'expeditions_screen.dart';
import 'forge_screen.dart';
import 'hall_common.dart';
import 'hall_habits.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_status.dart';
import 'hall_voice.dart';
import 'ritual_screen.dart';
import 'vault_screen.dart';

/// What every home section is handed.
class HallHomeData {
  const HallHomeData({
    required this.game,
    required this.view,
    required this.voice,
    required this.now,
    required this.onOpenLedger,
    required this.links,
  });

  final GameState game;
  final HallLedgerView view;
  final HallVoice voice;
  final DateTime now;
  final VoidCallback onOpenLedger;
  final HallLinks links;

  PersonState get me => game.person(view.meId ?? '');
  GameDay get today => GameDay.fromInstant(now);
}

// ---------------------------------------------------------------------------
// The party
// ---------------------------------------------------------------------------

class PartyHeader extends StatelessWidget {
  const PartyHeader(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final me = data.me;
    final streak = liveStreak(me.streak, data.today, tokens: me.freezeTokens);
    final greeting = data.voice.line('greetings', seed: data.today.toKey());
    final scheme = Theme.of(context).colorScheme;
    return HallSection(
      title: 'The party',
      icon: Icons.groups_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (greeting.isNotEmpty) ...[
            Text(greeting,
                style: hallBodyStyle(context, color: scheme.onSurfaceVariant)
                    .copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              _Stat(
                sprite: GameAssetKeys.gem,
                text: HallNames.gems(me.gems),
                tooltip: Glossary.gems.helper,
              ),
              _Stat(
                sprite: GameAssetKeys.freezeToken,
                text: '${me.freezeTokens} '
                    '${Glossary.freezeToken.adventure}'
                    '${me.freezeTokens == 1 ? '' : 's'}',
                tooltip: Glossary.freezeToken.helper,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(_streakText(streak), style: hallBodyStyle(context)),
          const SizedBox(height: AppSpacing.md),
          for (final adult in data.view.adults)
            _MemberRow(adult: adult, data: data),
        ],
      ),
    );
  }

  static String _streakText(LiveStreak s) {
    if (s.isEmpty) return 'Streak: start a fresh one today.';
    final days = '${s.days} day${s.days == 1 ? '' : 's'}';
    final frozen = s.frozenDays > 0
        ? ' (${s.frozenDays} kept by freeze token${s.frozenDays == 1 ? '' : 's'})'
        : '';
    final tokens =
        s.coveredByTokens ? ' — your freeze tokens will bridge the gap' : '';
    return 'Streak: $days$frozen$tokens';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.sprite, required this.text, this.tooltip});

  final AssetKey sprite;
  final String text;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip ?? '',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameSprite.fromKey(sprite, scale: 1),
            const SizedBox(width: AppSpacing.xs),
            Text(text, style: hallBodyStyle(context, weight: FontWeight.w700)),
          ],
        ),
      );
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.adult, required this.data});

  final HallAdult adult;
  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final person = data.game.person(adult.memberId);
    final isMe = adult.memberId == data.view.meId;
    final String role;
    if (adult.inAdventure) {
      final heroName = person.hero.cosmetics['name'];
      final title = person.hero.cosmetics['title'];
      role = [
        if (heroName != null && heroName.isNotEmpty) heroName,
        if (title != null && title.isNotEmpty) title,
        'Hero · power ${person.hero.power}',
      ].join(' · ');
    } else {
      final deliveries = caravanDeliveries(person);
      role = deliveries > 0
          ? '${_cap(Glossary.supplyCaravan.adventure)} · '
              '$deliveries deliver${deliveries == 1 ? 'y' : 'ies'} to the stores'
          : '${_cap(Glossary.supplyCaravan.adventure)} · '
              '${data.voice.line('caravan', seed: adult.memberId)}';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          GameSprite.fromKey(
            adult.inAdventure
                ? GameAssetKeys.heroPortrait
                : GameAssetKeys.supplyCaravan,
            label: adult.name,
            baseSize: kPortraitBaseSize,
            scale: 1,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isMe ? '${adult.name} (you)' : adult.name,
                    style: hallBodyStyle(context, weight: FontWeight.w700)),
                Text(role, style: hallMutedStyle(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ---------------------------------------------------------------------------
// Today: the Scribe's Desk, no-spend check-in, weekly reconcile
// ---------------------------------------------------------------------------

class HabitPanel extends ConsumerStatefulWidget {
  const HabitPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  ConsumerState<HabitPanel> createState() => _HabitPanelState();
}

class _HabitPanelState extends ConsumerState<HabitPanel> {
  bool _busy = false;
  bool _checkedIn = false;
  bool _reconciled = false;

  static const unavailableNote =
      'Check-ins and weekly reconciles switch on once your household adopts '
      'the savings rules in Settings (update every device first).';

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final available = data.view.habitsAvailable;
    final covered = _checkedIn || todayCovered(data.me, data.today);
    final reconciled = _reconciled || weekReconciled(data.me, data.today);
    return HallSection(
      title: 'Today',
      icon: Icons.edit_note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScribeRow(data: data),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              OutlinedButton.icon(
                onPressed: available && !covered && !_busy ? _noSpend : null,
                icon: Icon(covered ? Icons.check : Icons.nights_stay_outlined),
                label: Text(covered ? 'Today already counts' : 'No spend today'),
              ),
              OutlinedButton.icon(
                onPressed:
                    available && !reconciled && !_busy ? _reconcile : null,
                icon: Icon(reconciled ? Icons.check : Icons.fact_check_outlined),
                label: Text(reconciled
                    ? 'Week reconciled'
                    : 'Reconcile this week'),
              ),
            ],
          ),
          if (!available) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(unavailableNote, style: hallMutedStyle(context)),
          ],
        ],
      ),
    );
  }

  Future<void> _noSpend() async {
    final habits = ref.read(hallHabitsProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (habits == null) return;
    setState(() => _busy = true);
    final ok = await habits.checkInNoSpend();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _checkedIn = ok;
    });
    messenger?.showSnackBar(SnackBar(
      content: Text(ok
          ? widget.data.voice
              .line('noSpendDone', seed: widget.data.today.toKey())
          : unavailableNote),
    ));
  }

  Future<void> _reconcile() async {
    final habits = ref.read(hallHabitsProvider);
    if (habits == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => HallScope(
          child: AlertDialog(
        title: const Text('Reconcile this week?'),
        content: const Text(
            "Check this week's entries against your receipts or bank, add "
            'anything missing, then mark the week done.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('ledger'),
            child: const Text('Open the ledger'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('done'),
            child: const Text('Mark reconciled'),
          ),
        ],
      )),
    );
    if (!mounted) return;
    if (choice == 'ledger') {
      widget.data.onOpenLedger();
      return;
    }
    if (choice != 'done') return;
    setState(() => _busy = true);
    final ok = await habits.completeReconcile(widget.data.today);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _reconciled = ok;
    });
    messenger?.showSnackBar(SnackBar(
      content: Text(ok
          ? widget.data.voice.line('reconcileDone',
              seed: widget.data.today.weekStart.toKey())
          : unavailableNote),
    ));
  }
}

class _ScribeRow extends StatelessWidget {
  const _ScribeRow({required this.data});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final tier = data.game.hall.completedTier(BuildingType.scribesDesk, data.now);
    return Row(
      children: [
        GameSprite.fromKey(
            GameAssetKeys.building(BuildingType.scribesDesk, tier < 1 ? 1 : tier),
            label: Glossary.scribesDesk.adventure,
            scale: 1),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Glossary.scribesDesk.adventure,
                  style: hallBodyStyle(context, weight: FontWeight.w700)),
              Text('Budgets, the ledger and settings.',
                  style: hallMutedStyle(context)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: data.onOpenLedger,
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('Open the ledger'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inbox: unopened chests and unclaimed rewards
// ---------------------------------------------------------------------------

class InboxPanel extends ConsumerWidget {
  const InboxPanel(this.data, {super.key});

  final HallHomeData data;

  /// The most rewards listed one by one; the rest fold into "Claim all".
  static const maxRewardRows = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = data.me;
    final chests = me.unopenedChests.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final rewards = me.unclaimedRewards.values.toList()
      ..sort((a, b) {
        final t = a.grantedAt.compareTo(b.grantedAt);
        return t != 0 ? t : a.rewardId.compareTo(b.rewardId);
      });
    if (chests.isEmpty && rewards.isEmpty) {
      return HallSection(
        title: 'Inbox',
        icon: Icons.inbox_outlined,
        child: Text('Nothing waiting. Log something and see what turns up.',
            style: hallMutedStyle(context)),
      );
    }
    return HallSection(
      title: 'Inbox',
      icon: Icons.inbox_outlined,
      trailing: rewards.length > 1
          ? TextButton(
              onPressed: () => _claimAll(context, ref, rewards),
              child: Text('Claim all (${rewards.length})'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in chests)
            _InboxRow(
              sprite: GameSprite.fromKey(GameAssetKeys.chest(c.value),
                  label: HallNames.chest(c.value), scale: 1),
              title: HallNames.chest(c.value),
              subtitle: _chestReason(c.key),
              action: 'Open',
              onPressed: () => _open(context, ref, c.key, c.value),
            ),
          for (final r in rewards.take(maxRewardRows))
            _InboxRow(
              sprite: GameSprite.fromKey(
                  r.loot.gems > 0
                      ? GameAssetKeys.gem
                      : r.loot.tokens > 0
                          ? GameAssetKeys.freezeToken
                          : GameAssetKeys.material(
                              r.loot.materials.amounts.keys.isEmpty
                                  ? MaterialKind.lumber
                                  : r.loot.materials.amounts.keys.first),
                  scale: 1),
              title: data.voice.reason(r.reasonCode),
              subtitle: HallNames.loot(r.loot),
              action: 'Claim',
              onPressed: () => _claim(context, ref, r),
            ),
          if (rewards.length > maxRewardRows)
            Text('…and ${rewards.length - maxRewardRows} more',
                style: hallMutedStyle(context)),
        ],
      ),
    );
  }

  String _chestReason(String chestId) {
    final code = chestId.split(':').first;
    return data.voice.reason(code);
  }

  Future<void> _open(
      BuildContext context, WidgetRef ref, String chestId, ChestType type) async {
    final r = await runHallCommand(context, ref, (s) => s.openChest(chestId));
    if (r == null || !r.accepted || !context.mounted) return;
    final opened = r.events.whereType<ChestOpened>().firstOrNull;
    if (opened == null) return;
    await showHallCelebration(
      context,
      sprite: GameAssetKeys.chest(type, open: true),
      title: data.voice.line('chestOpened',
              seed: opened.eventId,
              fill: {'chest': HallNames.chest(type).toLowerCase()}),
      lines: ['Inside: ${HallNames.loot(opened.contents)}.'],
    );
  }

  Future<void> _claim(
      BuildContext context, WidgetRef ref, PendingReward reward) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final r =
        await runHallCommand(context, ref, (s) => s.claimReward(reward.rewardId));
    if (r == null || !r.accepted) return;
    messenger?.showSnackBar(SnackBar(
      content: Text('${_cap(HallNames.loot(reward.loot))}. '
          '${data.voice.line('rewardClaimed', seed: reward.rewardId)}'),
    ));
  }

  Future<void> _claimAll(
      BuildContext context, WidgetRef ref, List<PendingReward> rewards) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    var gems = 0;
    var tokens = 0;
    var materials = const MaterialBundle.empty();
    for (final reward in rewards) {
      final r = await runHallCommand(
          context, ref, (s) => s.claimReward(reward.rewardId));
      if (r == null || !r.accepted) continue;
      gems += reward.loot.gems;
      tokens += reward.loot.tokens;
      materials = materials + reward.loot.materials;
    }
    final total = Loot(gems: gems, tokens: tokens, materials: materials);
    if (total.isEmpty) return;
    messenger?.showSnackBar(SnackBar(
      content: Text('Claimed ${HallNames.loot(total)}. '
          '${data.voice.line('rewardClaimed', seed: rewards.length)}'),
    ));
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({
    required this.sprite,
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onPressed,
  });

  final Widget sprite;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            sprite,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: hallBodyStyle(context, weight: FontWeight.w700)),
                  Text(subtitle, style: hallMutedStyle(context)),
                ],
              ),
            ),
            FilledButton.tonal(onPressed: onPressed, child: Text(action)),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// The spoils ritual callout
// ---------------------------------------------------------------------------

class RitualCallout extends StatelessWidget {
  const RitualCallout(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final pending = pendingRitualMonths(data.me, data.now);
    if (pending.isEmpty) return const SizedBox.shrink();
    // A ritual already under way first; otherwise the month just ended.
    final month = pending.firstWhere(
        (m) => (data.me.ritual[m]?.steps.length ?? 0) > 0,
        orElse: () => pending.last);
    final done = data.me.ritual[month]?.steps.length ?? 0;
    final scheme = Theme.of(context).colorScheme;
    return HallSection(
      title: 'The ${Glossary.monthRitual.adventure} awaits',
      icon: Icons.auto_awesome,
      accent: scheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${monthLabel(month.year, month.month)}: $done of '
            '${RitualStep.values.length} steps done. Finish them to face the '
            'seasonal boss and earn the spoils chest.',
            style: hallBodyStyle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => openRitual(context, data),
            icon: const Icon(Icons.auto_awesome),
            label: Text(done == 0 ? 'Begin the ritual' : 'Continue the ritual'),
          ),
        ],
      ),
    );
  }
}

/// Pushes the ritual screen.
void openRitual(BuildContext context, HallHomeData data) =>
    pushHallScreen(context,
        RitualScreen(onOpenLedger: data.onOpenLedger, links: data.links));

// ---------------------------------------------------------------------------
// The shared stores
// ---------------------------------------------------------------------------

class StoresPanel extends StatelessWidget {
  const StoresPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final hall = data.game.hall;
    final capacity = hall.storageCapacityAt(data.now);
    final text = hallTextTier(context);
    return HallSection(
      title: 'Party stores',
      icon: Icons.inventory_2_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('The Storehouse holds up to $capacity of each material.',
              style: hallMutedStyle(context)),
          const SizedBox(height: AppSpacing.sm),
          for (final m in cappedMaterials)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                children: [
                  if (!text) ...[
                    GameSprite.fromKey(GameAssetKeys.material(m), scale: 1),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  SizedBox(
                    width: 72,
                    child: Text(HallNames.material(m),
                        style: hallBodyStyle(context)),
                  ),
                  SizedBox(
                    width: 84,
                    child: Text('${hall.materials[m]}/$capacity',
                        textAlign: TextAlign.right,
                        style: hallBodyStyle(context)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: HallBar(
                        capacity == 0 ? 0 : hall.materials[m] / capacity,
                        width: 10),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          Text(
              '${HallNames.material(MaterialKind.trophy)} on the mantel: '
              '${hall.materials[MaterialKind.trophy]}',
              style: hallBodyStyle(context)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plots
// ---------------------------------------------------------------------------

class PlotsPanel extends StatelessWidget {
  const PlotsPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) => HallSection(
        title: 'The hall grounds',
        icon: Icons.castle_outlined,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (var i = 0; i < Balance.maxPlots; i++)
              PlotTile(index: i, data: data),
          ],
        ),
      );
}

class PlotTile extends StatelessWidget {
  const PlotTile({super.key, required this.index, required this.data});

  final int index;
  final HallHomeData data;

  static const double width = 104;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plot = data.game.hall.plots[index];
    final b = plot?.building;
    final now = data.now;
    final text = hallTextTier(context);

    final Widget sprite;
    final String title;
    final String status;
    if (plot == null) {
      final cost = Balance.plotUnlockCost(index);
      sprite = GameSprite.fromKey(GameAssetKeys.panel('hall_plot'),
          label: 'Locked', scale: 2);
      title = 'Locked';
      status = cost == null ? '' : 'Unlock: ${HallNames.gems(cost)}';
    } else if (b == null) {
      sprite = GameSprite.fromKey(GameAssetKeys.panel('hall_plot'),
          label: 'Empty', scale: 2);
      title = 'Empty plot';
      status = 'Tap to build';
    } else {
      final complete = b.isCompleteAt(now);
      sprite = GameSprite.fromKey(
        GameAssetKeys.building(b.type, b.tier,
            state: complete ? 'idle' : 'constructing'),
        label: HallNames.building(b.type),
        scale: 2,
      );
      title = '${HallNames.building(b.type)} T${b.tier}';
      if (!complete) {
        status = 'Ready in ${HallNames.duration(b.completesAt.difference(now))}';
      } else if (Balance.buildings[b.type]!.isProducer) {
        final ready = collectableNow(data.game.hall, index, now);
        status = ready.isEmpty ? 'Working…' : '+${HallNames.bundle(ready)}';
      } else {
        status = 'Tier ${b.tier}';
      }
    }

    final semantics = '$title. $status';
    return Semantics(
      button: true,
      label: semantics,
      child: InkWell(
        borderRadius: AppRadii.card,
        onTap: () => showBuildingSheet(context,
            plotIndex: index,
            onOpenLedger: data.onOpenLedger,
            links: data.links),
        child: Container(
          width: width,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: AppRadii.card,
            border: Border.all(
              color: plot == null ? scheme.outlineVariant : scheme.outline,
              width: text ? 1 : 2,
            ),
            color: plot == null
                ? scheme.surfaceContainerLowest
                : scheme.surfaceContainerHigh,
          ),
          child: Column(
            children: [
              ExcludeSemantics(child: sprite),
              const SizedBox(height: AppSpacing.xs),
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: hallBodyStyle(context, weight: FontWeight.w700)
                      .copyWith(fontSize: 12)),
              Text(status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: hallMutedStyle(context).copyWith(fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Places
// ---------------------------------------------------------------------------

class PlacesPanel extends StatelessWidget {
  const PlacesPanel(this.data, {super.key});

  final HallHomeData data;

  @override
  Widget build(BuildContext context) {
    final me = data.me;
    final hall = data.game.hall;
    final forgeTier = hall.completedTier(BuildingType.forge, data.now);
    final trip = me.activeExpedition;
    final String tripStatus;
    if (trip == null) {
      tripStatus = 'The hero is home. Send them out for materials.';
    } else if (data.now.isBefore(trip.endsAt)) {
      tripStatus = 'Away in ${HallNames.region(trip.region)} · back in '
          '${HallNames.duration(trip.endsAt.difference(data.now))}';
    } else {
      tripStatus = 'Back from ${HallNames.region(trip.region)} with a report!';
    }
    final pending = pendingRitualMonths(me, data.now);
    return HallSection(
      title: 'Around the hall',
      icon: Icons.signpost_outlined,
      child: Column(
        children: [
          _PlaceTile(
            icon: Icons.hardware_outlined,
            title: 'Forge & hero',
            subtitle: forgeTier == 0
                ? 'Hero power ${me.hero.power} · build a Forge to craft gear'
                : 'Hero power ${me.hero.power} · Forge tier $forgeTier',
            onTap: () => pushHallScreen(context, const ForgeScreen()),
          ),
          _PlaceTile(
            icon: Icons.explore_outlined,
            title: 'Expeditions',
            subtitle: tripStatus,
            onTap: () => pushHallScreen(context, const ExpeditionsScreen()),
          ),
          _PlaceTile(
            icon: Icons.savings_outlined,
            title: 'Vault',
            subtitle: 'Savings milestones: goal progress and saving streaks',
            onTap: () => pushHallScreen(
                context, VaultScreen(onOpenLedger: data.onOpenLedger)),
          ),
          _PlaceTile(
            icon: Icons.auto_awesome,
            title: _cap(Glossary.monthRitual.adventure),
            subtitle: pending.isEmpty
                ? 'All done for now. The next one opens when the month ends.'
                : '${pending.length} month${pending.length == 1 ? '' : 's'} '
                    'ready for the ritual',
            onTap: () => openRitual(context, data),
          ),
        ],
      ),
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: hallBodyStyle(context, weight: FontWeight.w700)),
                    Text(subtitle, style: hallMutedStyle(context)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
}
