/// The month-end spoils ritual: four steps (reconcile, review, plan,
/// contribute), each linking to the ledger screen where the real work
/// happens, and each marked done by the person when they've done it. Then the
/// seasonal boss, shown turn by turn from the stored fight result. Win or
/// lose, the spoils chest arrives: the ritual earned it, and the losing copy
/// is supportive.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/time.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../domain/content.dart';
import '../domain/game_event.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../game_sprite.dart';
import 'hall_common.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_status.dart';
import 'hall_voice.dart';

class RitualScreen extends ConsumerWidget {
  const RitualScreen({
    super.key,
    required this.onOpenLedger,
    this.links = const HallLinks(),
  });

  final VoidCallback onOpenLedger;
  final HallLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final now = hallNow(ref);
    final me = game.person(view.meId ?? '');
    final current = Month.fromInstant(now);
    return Scaffold(
      appBar: AppBar(title: Text(_cap(Glossary.monthRitual.adventure))),
      body: HallPage(children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
              '${Glossary.monthRitual.helper} Then face the seasonal boss. '
              'Win or lose, the spoils chest is yours. The ritual for '
              '${monthLabel(current.year, current.month)} opens when the '
              'month ends.',
              style: hallMutedStyle(context)),
        ),
        for (final m in openRitualMonths(now))
          _MonthRitual(
            month: m,
            progress: me.ritual[m] ?? const RitualProgress(),
            voice: voice,
            onOpenLedger: onOpenLedger,
            links: links,
          ),
      ]),
    );
  }
}

class _MonthRitual extends ConsumerWidget {
  const _MonthRitual({
    required this.month,
    required this.progress,
    required this.voice,
    required this.onOpenLedger,
    required this.links,
  });

  final Month month;
  final RitualProgress progress;
  final HallVoice voice;
  final VoidCallback onOpenLedger;
  final HallLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = progress.steps;
    final nextStep =
        RitualStep.values.where((s) => !done.contains(s)).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final boss = Balance.bosses[seasonOf(month)]!;
    final bossName = voice.bossName(boss.key);
    final fought = progress.boss;
    return HallSection(
      title: monthLabel(month.year, month.month),
      icon: Icons.auto_awesome,
      accent: fought == null ? scheme.tertiary : scheme.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, step) in RitualStep.values.indexed)
            _StepRow(
              number: i + 1,
              step: step,
              done: done.contains(step),
              isNext: step == nextStep,
              onOpen: () {
                final link = links.forStep(step);
                if (link != null) {
                  link(context, month);
                } else {
                  onOpenLedger();
                }
              },
              onMarkDone: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final r = await runHallCommand(
                    context, ref, (s) => s.completeRitualStep(month, step));
                if (r != null && r.accepted) {
                  messenger?.showSnackBar(SnackBar(
                      content: Text(voice.line('ritualStepDone',
                          seed: r.events.first.eventId))));
                }
              },
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              GameSprite.fromKey(GameAssetKeys.boss(boss.key),
                  label: bossName, scale: 2),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: fought != null
                    ? Text(
                        fought.won
                            ? '${_cap(bossName)} fell in ${fought.turns} '
                                'turn${fought.turns == 1 ? '' : 's'}.'
                            : '${_cap(bossName)} slipped away. The spoils '
                                'were yours all the same.',
                        style: hallBodyStyle(context))
                    : Text(
                        nextStep == null
                            ? '${_cap(bossName)} awaits.'
                            : 'Finish the steps to summon $bossName.',
                        style: hallBodyStyle(context)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (fought != null)
            OutlinedButton.icon(
              onPressed: () => pushHallScreen(
                  context,
                  BossFightScreen(
                      month: month, result: fought, seed: month.toKey())),
              icon: const Icon(Icons.replay),
              label: const Text('Replay the fight'),
            )
          else
            FilledButton.icon(
              onPressed: nextStep == null ? () => _fight(context, ref) : null,
              icon: const Icon(Icons.local_fire_department),
              label: Text('Face $bossName'),
            ),
        ],
      ),
    );
  }

  Future<void> _fight(BuildContext context, WidgetRef ref) async {
    final r = await runHallCommand(context, ref, (s) => s.fightBoss(month));
    if (r == null || !r.accepted || !context.mounted) return;
    final e = r.events.whereType<BossFightResolved>().firstOrNull;
    if (e == null) return;
    await pushHallScreen(
      context,
      BossFightScreen(
        month: month,
        seed: e.eventId,
        result: BossResult(
            bossKey: e.bossKey, won: e.won, turns: e.turns, rewards: e.rewards),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.step,
    required this.done,
    required this.isNext,
    required this.onOpen,
    required this.onMarkDone,
  });

  final int number;
  final RitualStep step;
  final bool done;
  final bool isNext;
  final VoidCallback onOpen;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final text = hallTextTier(context);
    final scheme = Theme.of(context).colorScheme;
    final mark = text
        ? Text(done ? '[x]' : '[ ]',
            style: hallBodyStyle(context, weight: FontWeight.w700))
        : Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: done ? scheme.primary : scheme.outline, size: 20);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$number. ${HallNames.ritualStep(step)}',
                    style: hallBodyStyle(context, weight: FontWeight.w700)),
                if (!done)
                  Text(HallNames.ritualStepBlurb(step),
                      style: hallMutedStyle(context)),
                if (isNext)
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        onPressed: onOpen,
                        child: Text(HallNames.ritualStepLink(step)),
                      ),
                      FilledButton.tonal(
                        onPressed: onMarkDone,
                        child: const Text('Mark done'),
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
}

/// The seasonal boss fight, revealed turn by turn from the stored result.
/// The fight was settled when the command ran (and is the same on every
/// device); this only narrates it.
class BossFightScreen extends ConsumerStatefulWidget {
  const BossFightScreen({
    super.key,
    required this.month,
    required this.result,
    required this.seed,
  });

  final Month month;
  final BossResult result;

  /// Seeds the narration picks (the fight event's id, or the month).
  final String seed;

  @override
  ConsumerState<BossFightScreen> createState() => _BossFightScreenState();
}

class _BossFightScreenState extends ConsumerState<BossFightScreen> {
  int _shown = 0;

  bool get _over => _shown >= widget.result.turns;

  /// The boss's remaining health after [turn] turns, for the bar. A win ends
  /// empty; a retreat ends with the beast wounded but standing.
  double _hpAfter(int turn) {
    final turns = widget.result.turns;
    if (turns == 0) return 1;
    final f = widget.result.won ? turn / turns : turn / (turns + 1);
    return 1 - f;
  }

  @override
  Widget build(BuildContext context) {
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final r = widget.result;
    final name = voice.bossName(r.bossKey);
    final fill = {'boss': _cap(name)};
    return Scaffold(
      appBar: AppBar(
          title: Text(
              'Boss fight — ${monthLabel(widget.month.year, widget.month.month)}')),
      body: HallPage(children: [
        HallSection(
          title: _cap(name),
          icon: Icons.local_fire_department,
          accent: Theme.of(context).colorScheme.tertiary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GameSprite.fromKey(
                  GameAssetKeys.boss(r.bossKey,
                      state: _over && r.won ? 'defeated' : 'idle'),
                  label: _cap(name),
                  scale: 4,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text('HP ', style: hallBodyStyle(context)),
                  Expanded(child: HallBar(_hpAfter(_shown), width: 20)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(voice.line('bossIntro', seed: widget.seed, fill: fill),
                  style: hallBodyStyle(context, weight: FontWeight.w700)),
              for (var t = 1; t <= _shown; t++)
                Text(
                    'Turn $t: ${voice.line('bossTurns', seed: '${widget.seed}#$t', fill: fill)}',
                    style: hallBodyStyle(context)),
              if (_over) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                    voice.line(r.won ? 'bossWin' : 'bossLoss',
                        seed: widget.seed, fill: fill),
                    style: hallBodyStyle(context, weight: FontWeight.w800)),
                if (r.won && !r.rewards.isEmpty)
                  Text('Won: ${HallNames.loot(r.rewards)}.',
                      style: hallBodyStyle(context)),
                Text(voice.line('spoilsChest', seed: widget.seed),
                    style: hallMutedStyle(context)),
              ],
              const SizedBox(height: AppSpacing.md),
              if (!_over)
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    FilledButton(
                      onPressed: () => setState(() => _shown++),
                      child: const Text('Next turn'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _shown = r.turns),
                      child: const Text('Skip to the end'),
                    ),
                  ],
                )
              else
                FilledButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Back to the hall'),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
