/// The Funds hub (Adventure: the Treasury): one first-class destination for
/// the household's pooled money — the war chest (shared savings), emergency
/// funds and vacations — plus the homestead that visualizes the war chest.
/// Each card summarizes its numbers (all read from the reducer's state) and
/// opens the full screen. An open vacation leads the page.
///
/// Rendered as a shell pane (no app bar of its own); the shell's app bar
/// carries the title.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../ui/format.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../../ui/widgets/app_card.dart';
import '../homestead/homestead_screen.dart';
import '../household_context.dart';
import '../settings/emergency_funds_screen.dart';
import '../settings/play_mode_providers.dart';
import '../vacation/vacation_dashboard.dart';
import '../vacation/vacation_screen.dart';
import '../warchest/advance_model.dart';
import '../warchest/warchest_screen.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class FundsScreen extends ConsumerWidget {
  const FundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);
    final homestead = ref.watch(homesteadViewProvider);
    final adventure = ref.watch(isAdventureProvider);
    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);

    // ---- War chest ------------------------------------------------------
    final chest = state.warChest;
    final writsForMe = state.withdrawals.values
        .where(
          (w) => w.status == WithdrawalStatus.pending && w.byUserId != meUserId,
        )
        .length;
    final advancesForMe = buildPendingAdvances(
      state,
      meUserId: meUserId,
      userNames: names,
    ).where((a) => a.canApprove).length;
    final waiting = writsForMe + advancesForMe;

    // ---- Emergency funds --------------------------------------------------
    final funds = state.emergencyFunds.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final fundsTotal = funds.fold<int>(0, (t, f) => t + f.balanceCents);
    final fundsLabel =
        '${_cap(Glossary.emergencyFund.label(isAdventure: adventure))}s';

    // ---- Vacations --------------------------------------------------------
    final open = state.openVacations;
    final closedCount = state.vacations.length - open.length;
    final vacationsLabel =
        '${_cap(Glossary.vacation.label(isAdventure: adventure))}s';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: [
        for (final v in open) ...[
          _OpenVacationCard(vacation: v, adventure: adventure),
          const SizedBox(height: AppSpacing.md),
        ],
        _HubCard(
          icon: Icons.account_balance_outlined,
          title: 'War chest',
          trailing: money(chest.balanceCents),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const WarChestScreen()),
          ),
          children: [
            Text(
              adventure
                  ? 'The party’s shared hoard — writs, gifts and refunds.'
                  : 'The household’s shared savings — withdrawals, gifts and '
                        'refunds.',
              style: muted,
            ),
            if (chest.goal != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: chest.goal!.pctComplete.clamp(0.0, 1.0),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${(chest.goal!.pctComplete * 100).round()}% of '
                '${money(chest.targetCents!)}',
                style: muted,
              ),
            ],
            if (waiting > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                waiting == 1
                    ? '1 request is waiting for your approval'
                    : '$waiting requests are waiting for your approval',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _HubCard(
          icon: Icons.medical_services_outlined,
          title: fundsLabel,
          trailing: funds.isEmpty ? null : money(fundsTotal),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const EmergencyFundsScreen(),
            ),
          ),
          children: [
            if (funds.isEmpty)
              Text(
                'None yet. Name a fund for the unexpected — a vet bill, a car '
                'repair — and budgets can set money aside into it each month.',
                style: muted,
              )
            else
              for (final f in funds)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.petId == null
                              ? f.name
                              : '${f.name} · ${state.pets[f.petId]?.name ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      Text(money(f.balanceCents), style: textTheme.bodyMedium),
                    ],
                  ),
                ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _HubCard(
          icon: Icons.beach_access_outlined,
          title: vacationsLabel,
          onTap: () => VacationScreen.open(context),
          children: [
            Text(
              open.isNotEmpty
                  ? [
                      '${open.length} open',
                      if (closedCount > 0) '$closedCount past',
                    ].join(' · ')
                  : 'Plan a trip as its own budget, drawn from a savings goal '
                        'or emergency fund. Monthly budgets stay untouched.',
              style: muted,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _HubCard(
          icon: Icons.cottage_outlined,
          title: homestead?.flavorName ?? 'Homestead',
          onTap: () => HomesteadScreen.open(context),
          children: [
            Text(
              homestead == null
                  ? 'Watch the war chest build up, stage by stage.'
                  : 'Stage ${homestead.stageNumber} of '
                        '${homestead.totalStages} · '
                        '${homestead.currentStage.name}',
              style: muted,
            ),
          ],
        ),
      ],
    );
  }
}

/// A tappable summary card that opens one of the hub's screens.
class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
    this.children = const [],
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: AppText.metricValue(context)),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
          if (children.isNotEmpty) const SizedBox(height: AppSpacing.xs),
          ...children,
        ],
      ),
    );
  }
}

/// An open vacation, led at the top of the hub: spend against the trip
/// budget, the daily allowance left, and any overspend warnings.
class _OpenVacationCard extends StatelessWidget {
  const _OpenVacationCard({required this.vacation, required this.adventure});

  final VacationState vacation;
  final bool adventure;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final v = vacation;
    final warnings = vacationWarnings(v);
    final budget = v.totalLimitCents;
    final fraction = budget <= 0
        ? (v.totalSpentCents > 0 ? 1.0 : 0.0)
        : (v.totalSpentCents / budget).clamp(0.0, 1.0);
    final onColor = scheme.onTertiaryContainer;
    return AppCard(
      color: scheme.tertiaryContainer,
      onTap: () => VacationScreen.open(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.beach_access, color: onColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${adventure ? 'Expedition abroad' : 'On vacation'} · '
                  '${v.name}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: onColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: onColor),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: warnings.isEmpty ? scheme.tertiary : scheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${money(v.totalSpentCents)} of ${money(budget)} spent · '
            '${dailyAllowanceLabel(v)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: onColor),
          ),
          for (final w in warnings)
            Text(
              w,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
