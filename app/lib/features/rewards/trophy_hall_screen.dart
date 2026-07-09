/// The Trophy Hall — the party's cosmetic rewards: defeated-quest trophies and
/// habit-streak titles/badges, plus the live streak counters that drive them.
///
/// Text-mode-first: everything renders as styled text panels, so the hall is
/// complete before any pixel art exists. Rewards shown here are the persistent,
/// synced record ([GameRewardGranted] events); the streak counters are derived
/// read-time. This is the display side of the firewall — nothing here moves a
/// cent.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/event.dart';
import '../../domain/value_types.dart';
import '../../game/rewards/rewards.dart';
import '../../game/text_mode/text_widgets.dart';
import '../../ui/theme.dart';

class TrophyHallScreen extends ConsumerWidget {
  const TrophyHallScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const TrophyHallScreen()),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final granted = ref.watch(grantedRewardsProvider);
    final snapshot = ref.watch(rewardsSnapshotProvider);
    final state = ref.watch(householdStateProvider).value;
    final questNames = <String, String>{
      if (state != null)
        for (final q in state.quests.values) q.questId: q.name,
    };

    final trophies =
        granted.where((r) => r.kind == RewardKind.trophy).toList();
    final titles = granted.where((r) => r.kind == RewardKind.title).toList();
    final badges = granted.where((r) => r.kind == RewardKind.badge).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Trophy hall')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (snapshot != null) _StreaksPanel(snapshot: snapshot),
          _RewardsPanel(
            title: 'Trophies',
            icon: Icons.emoji_events_outlined,
            empty: 'Defeat a savings-goal boss to earn your first trophy.',
            rewards: trophies,
            questNames: questNames,
          ),
          _RewardsPanel(
            title: 'Titles',
            icon: Icons.workspace_premium_outlined,
            empty: 'Log purchases day after day to earn logging-streak titles.',
            rewards: titles,
            questNames: questNames,
          ),
          _RewardsPanel(
            title: 'Badges',
            icon: Icons.military_tech_outlined,
            empty: 'Close the month on time to earn ritual badges.',
            rewards: badges,
            questNames: questNames,
          ),
        ],
      ),
    );
  }
}

class _StreaksPanel extends StatelessWidget {
  const _StreaksPanel({required this.snapshot});

  final RewardsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: 'Current streaks',
      icon: Icons.local_fire_department_outlined,
      accent: scheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Logging streak:  ${snapshot.dailyLogStreakDays} '
            'day${snapshot.dailyLogStreakDays == 1 ? '' : 's'}',
            style: monoStyle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'On-time rituals: ${snapshot.onTimeRitualStreakMonths} '
            'month${snapshot.onTimeRitualStreakMonths == 1 ? '' : 's'} in a row',
            style: monoStyle(context),
          ),
        ],
      ),
    );
  }
}

class _RewardsPanel extends StatelessWidget {
  const _RewardsPanel({
    required this.title,
    required this.icon,
    required this.empty,
    required this.rewards,
    required this.questNames,
  });

  final String title;
  final IconData icon;
  final String empty;
  final List<GameRewardGranted> rewards;
  final Map<String, String> questNames;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextPanel(
      title: '$title (${rewards.length})',
      icon: icon,
      child: rewards.isEmpty
          ? Text(empty, style: monoStyle(context, color: scheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in rewards)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('★ ${_describe(r)}', style: monoStyle(context)),
                  ),
              ],
            ),
    );
  }

  /// A display label reconstructed from the synced reward's deterministic
  /// [GameRewardGranted.sourceRef].
  String _describe(GameRewardGranted r) {
    final ref = r.sourceRef;
    if (r.kind == RewardKind.trophy) {
      final name = questNames[ref];
      return name == null ? 'Boss vanquished' : '$name vanquished';
    }
    if (ref.startsWith('daily:')) {
      return '${ref.substring('daily:'.length)}-day logging streak';
    }
    if (ref.startsWith('ritual:')) {
      final n = ref.substring('ritual:'.length);
      return n == '1' ? 'First on-time ritual' : '$n on-time rituals in a row';
    }
    return r.rewardId;
  }
}
