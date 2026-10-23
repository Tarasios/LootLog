/// The building sheet: everything about one hall plot. A locked plot shows
/// its unlock price; an empty plot lists what can be built there; a building
/// shows its tier, its build timer, what it has made (with a collect button
/// and a preview of what fits in the Storehouse), and its next upgrade with
/// cost, build time and — when it can't happen yet — why, in plain words.
///
/// Every gate is checked by dry-running the real command, so the sheet and
/// the command can never disagree.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/commands/game_commands.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../domain/hall_rules.dart';
import '../game_sprite.dart';
import 'expeditions_screen.dart';
import 'forge_screen.dart';
import 'hall_common.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_voice.dart';
import 'vault_screen.dart';

/// Opens the sheet for [plotIndex].
Future<void> showBuildingSheet(
  BuildContext context, {
  required int plotIndex,
  required VoidCallback onOpenLedger,
  HallLinks links = const HallLinks(),
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => HallScope(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: BuildingSheet(plotIndex: plotIndex, onOpenLedger: onOpenLedger),
        ),
      ),
    );

class BuildingSheet extends ConsumerWidget {
  const BuildingSheet({
    super.key,
    required this.plotIndex,
    required this.onOpenLedger,
  });

  final int plotIndex;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final clock = ref.watch(gameClockProvider);
    return HallTicker(builder: (context) {
      final now = clock.now();
      final ctx = _SheetContext(
        game: game,
        meId: view.meId,
        now: now,
        voice: voice,
        preview: (cmd) => previewRejection(game, view.meId, clock, cmd),
      );
      final plot = game.hall.plots[plotIndex];
      final List<Widget> body;
      if (plot == null) {
        body = _locked(context, ref, ctx);
      } else if (plot.building == null) {
        body = _empty(context, ref, ctx);
      } else {
        body = _built(context, ref, ctx, plot.building!);
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: body,
        ),
      );
    });
  }

  // ---- Locked ---------------------------------------------------------------

  List<Widget> _locked(BuildContext context, WidgetRef ref, _SheetContext c) {
    final cost = Balance.plotUnlockCost(plotIndex);
    final rejection = c.preview((g) => g.unlockPlot(plotIndex));
    return [
      _Header(
        sprite: GameSprite.fromKey(GameAssetKeys.panel('hall_plot'),
            label: 'Locked', scale: 3),
        title: 'Plot ${plotIndex + 1} — locked',
        subtitle: 'Open it up to make room for another building.',
      ),
      if (cost != null) ...[
        Text('Unlock cost: ${HallNames.gems(cost)} '
            '(you have ${HallNames.gems(c.me.gems)}).',
            style: hallBodyStyle(context)),
        const SizedBox(height: AppSpacing.sm),
        _Gate(rejection: rejection, voice: c.voice),
        FilledButton.icon(
          onPressed: rejection == null
              ? () async {
                  final r = await runHallCommand(
                      context, ref, (s) => s.unlockPlot(plotIndex));
                  if (r != null && r.accepted && context.mounted) {
                    _toast(context, 'Plot ${plotIndex + 1} is open. '
                        'Time to build!');
                  }
                }
              : null,
          icon: const Icon(Icons.lock_open),
          label: Text('Unlock for ${HallNames.gems(cost)}'),
        ),
      ],
    ];
  }

  // ---- Empty ----------------------------------------------------------------

  List<Widget> _empty(BuildContext context, WidgetRef ref, _SheetContext c) {
    final options = [
      for (final t in BuildingType.values)
        if (c.game.hall.plotOf(t) == null) t,
    ];
    return [
      _Header(
        sprite: GameSprite.fromKey(GameAssetKeys.panel('hall_plot'),
            label: 'Empty', scale: 3),
        title: 'Plot ${plotIndex + 1} — empty',
        subtitle: 'Choose what to build. Each building gets one plot.',
      ),
      if (options.isEmpty)
        Text('Every building already stands in the hall.',
            style: hallMutedStyle(context)),
      for (final t in options)
        _BuildOption(
          type: t,
          rejection: c.preview((g) => g.startBuilding(plotIndex, t)),
          context: c,
          onBuild: () => _build(context, ref, c, t, 1),
        ),
    ];
  }

  // ---- Built ----------------------------------------------------------------

  List<Widget> _built(
      BuildContext context, WidgetRef ref, _SheetContext c, BuildingState b) {
    final now = c.now;
    final complete = b.isCompleteAt(now);
    final inService = b.tierAt(now);
    final spec = Balance.buildings[b.type]!;
    final next = b.tier + 1;
    final hall = c.game.hall;

    final widgets = <Widget>[
      _Header(
        sprite: GameSprite.fromKey(
          GameAssetKeys.building(b.type, b.tier,
              state: complete ? 'idle' : 'constructing'),
          label: HallNames.building(b.type),
          scale: 3,
        ),
        title: '${HallNames.building(b.type)} — tier ${b.tier}',
        subtitle: HallNames.buildingBlurb(b.type),
      ),
    ];

    if (!complete) {
      final total = b.completesAt.difference(b.startedAt);
      final left = b.completesAt.difference(now);
      widgets.addAll([
        Text(
            b.tier == 1
                ? 'Under construction · ready in ${HallNames.duration(left)}'
                : 'Upgrading to tier ${b.tier} · ready in '
                    '${HallNames.duration(left)}',
            style: hallBodyStyle(context, weight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.xs),
        HallBar(total.inSeconds == 0
            ? 1
            : 1 - left.inSeconds / total.inSeconds),
        const SizedBox(height: AppSpacing.md),
      ]);
    }

    // Links into the places this building opens.
    final link = switch (b.type) {
      BuildingType.scribesDesk => (
          'Open the ledger',
          Icons.menu_book,
          () {
            Navigator.of(context).pop();
            onOpenLedger();
          }
        ),
      BuildingType.forge => (
          'Open the Forge',
          Icons.hardware_outlined,
          () => pushHallScreen(context, const ForgeScreen())
        ),
      BuildingType.vault => (
          'Open the Vault',
          Icons.savings_outlined,
          () => pushHallScreen(context, VaultScreen(onOpenLedger: onOpenLedger))
        ),
      BuildingType.centralHall => (
          'Plan an expedition',
          Icons.explore_outlined,
          () => pushHallScreen(context, const ExpeditionsScreen())
        ),
      _ => null,
    };
    if (link != null) {
      widgets.addAll([
        OutlinedButton.icon(
          onPressed: link.$3,
          icon: Icon(link.$2),
          label: Text(link.$1),
        ),
        const SizedBox(height: AppSpacing.md),
      ]);
    }

    if (b.type == BuildingType.storehouse) {
      widgets.add(Text(
          'Holds up to ${hall.storageCapacityAt(now)} of each material.',
          style: hallBodyStyle(context)));
      widgets.add(const SizedBox(height: AppSpacing.md));
    }

    if (spec.isProducer) {
      final made = uncollectedProduction(hall, plotIndex, now);
      final fits = collectableNow(hall, plotIndex, now);
      final rejection = c.preview((g) => g.collectMaterials(plotIndex));
      final rates = {
        for (final e in spec.productionPerHour.entries)
          e.key: inService < 1 ? 0 : e.value[inService - 1],
      };
      widgets.addAll([
        HallSection(
          title: 'Production',
          icon: Icons.factory_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                  inService < 1
                      ? 'Starts producing once it is built.'
                      : 'Makes ${[
                          for (final e in rates.entries)
                            '${e.value} ${HallNames.material(e.key)}'
                        ].join(' and ')} an hour.',
                  style: hallBodyStyle(context)),
              const SizedBox(height: AppSpacing.xs),
              MaterialLine(fits, prefix: 'Ready to collect: '),
              if (made != fits && !made.isEmpty)
                Text(
                    'The Storehouse has room for only part of the '
                    '${HallNames.bundle(made)} made.',
                    style: hallMutedStyle(context)),
              const SizedBox(height: AppSpacing.sm),
              _Gate(rejection: rejection, voice: c.voice),
              FilledButton.icon(
                onPressed: rejection == null
                    ? () async {
                        final r = await runHallCommand(context, ref,
                            (s) => s.collectMaterials(plotIndex));
                        if (r != null && r.accepted && context.mounted) {
                          _toast(
                              context,
                              'Collected ${HallNames.bundle(fits)}. '
                              '${c.voice.line('collected', seed: r.events.first.eventId, fill: {
                                    'building': HallNames.building(b.type)
                                  })}');
                        }
                      }
                    : null,
                icon: const Icon(Icons.move_to_inbox),
                label: const Text('Collect'),
              ),
            ],
          ),
        ),
      ]);
    }

    // Upgrade.
    if (next > Balance.maxBuildingTier) {
      widgets.add(Text(
          'At its finest: tier ${Balance.maxBuildingTier} is the top.',
          style: hallMutedStyle(context)));
    } else {
      final cost = Balance.buildingCost(b.type, next);
      final rejection = c.preview((g) => g.startBuilding(plotIndex, b.type));
      widgets.add(HallSection(
        title: 'Upgrade to tier $next',
        icon: Icons.upgrade,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CostLine(cost),
            Text('Build time: ${HallNames.buildTime(next)}',
                style: hallBodyStyle(context)),
            if (spec.isProducer && complete)
              Text("Upgrading collects what's ready first.",
                  style: hallMutedStyle(context)),
            const SizedBox(height: AppSpacing.sm),
            _Gate(
              rejection: rejection,
              voice: c.voice,
              detail: _detail(rejection, c, cost, b.type, next),
            ),
            FilledButton.icon(
              onPressed: rejection == null
                  ? () => _build(context, ref, c, b.type, next)
                  : null,
              icon: const Icon(Icons.construction),
              label: Text('Upgrade to tier $next'),
            ),
          ],
        ),
      ));
    }
    return widgets;
  }

  Future<void> _build(BuildContext context, WidgetRef ref, _SheetContext c,
      BuildingType type, int tier) async {
    final r =
        await runHallCommand(context, ref, (s) => s.startBuilding(plotIndex, type));
    if (r == null || !r.accepted || !context.mounted) return;
    final name = HallNames.building(type);
    _toast(
        context,
        tier == 1
            ? c.voice.line('buildStarted',
                seed: r.events.last.eventId, fill: {'building': name})
            : c.voice.line('upgradeStarted',
                seed: r.events.last.eventId,
                fill: {'building': name, 'tier': '$tier'}));
  }

  static void _toast(BuildContext context, String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The specifics behind a gate, in plain words.
String? _detail(GameRejection? r, _SheetContext c, Loot cost, BuildingType type,
    int tier) {
  switch (r) {
    case GameRejection.needsCentralHall:
      return 'Tier $tier needs the Central Hall at tier $tier.';
    case GameRejection.notEnoughGems:
      return 'You have ${HallNames.gems(c.me.gems)} of '
          '${HallNames.gems(cost.gems)}.';
    case GameRejection.notEnoughMaterials:
      final short = MaterialBundle({
        for (final e in cost.materials.amounts.entries)
          e.key: (e.value - c.game.hall.materials[e.key]).clamp(0, e.value),
      });
      return 'Still to gather: ${HallNames.bundle(short)}.';
    default:
      return null;
  }
}

class _SheetContext {
  const _SheetContext({
    required this.game,
    required this.meId,
    required this.now,
    required this.voice,
    required this.preview,
  });

  final GameState game;
  final String? meId;
  final DateTime now;
  final HallVoice voice;
  final GameRejection? Function(
      GameCommandResult Function(GameCommands commands) command) preview;

  PersonState get me => game.person(meId ?? '');
}

class _Header extends StatelessWidget {
  const _Header({
    required this.sprite,
    required this.title,
    required this.subtitle,
  });

  final Widget sprite;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sprite,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: hallBodyStyle(context, weight: FontWeight.w800)
                          .copyWith(fontSize: 18)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: hallMutedStyle(context)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// Why an action is not available yet (nothing when it is).
class _Gate extends StatelessWidget {
  const _Gate({required this.rejection, required this.voice, this.detail});

  final GameRejection? rejection;
  final HallVoice voice;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final r = rejection;
    if (r == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(voice.rejection(r),
              style: hallBodyStyle(context,
                  color: Theme.of(context).colorScheme.tertiary)),
          if (detail != null) Text(detail!, style: hallMutedStyle(context)),
        ],
      ),
    );
  }
}

class _BuildOption extends StatelessWidget {
  const _BuildOption({
    required this.type,
    required this.rejection,
    required this.context,
    required this.onBuild,
  });

  final BuildingType type;
  final GameRejection? rejection;
  final _SheetContext context;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext buildContext) {
    final cost = Balance.buildingCost(type, 1);
    return HallSection(
      title: HallNames.building(type),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameSprite.fromKey(GameAssetKeys.building(type, 1),
              label: HallNames.building(type), scale: 2),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(HallNames.buildingBlurb(type),
                    style: hallMutedStyle(buildContext)),
                const SizedBox(height: AppSpacing.xs),
                CostLine(cost),
                Text('Build time: ${HallNames.buildTime(1)}',
                    style: hallBodyStyle(buildContext)),
                const SizedBox(height: AppSpacing.sm),
                _Gate(
                  rejection: rejection,
                  voice: context.voice,
                  detail: _detail(rejection, context, cost, type, 1),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: rejection == null ? onBuild : null,
                    child: Text('Build ${HallNames.building(type)}'),
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
