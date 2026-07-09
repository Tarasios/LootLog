/// View models for the quick-entry charge chips.
///
/// A [ChargeChoice] is one tappable destination for a purchase; [ChargeGroup]s
/// bundle them into the visually distinct sections the keypad shows (personal
/// slices, group slices, Vault, active quests, emergency funds). These are
/// derived purely from [HouseholdState] so the entry view never reads the DB.
library;

import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/time.dart';
import '../../domain/value_types.dart';

/// The visually distinct kinds of charge destination.
enum ChargeGroupKind {
  personalSlice,
  groupSlice,
  vault,
  quest,
  emergency,
  vacation,
}

/// One tappable charge destination.
class ChargeChoice {
  const ChargeChoice({
    required this.target,
    required this.label,
    required this.kind,
    required this.supportsShared,
    this.subtitle,
  });

  final ChargeTarget target;
  final String label;
  final String? subtitle;
  final ChargeGroupKind kind;

  /// Whether a `shared` flag is valid here (personal slices and the vault only).
  final bool supportsShared;
}

/// A titled section of [ChargeChoice]s.
class ChargeGroup {
  const ChargeGroup({required this.kind, required this.label, required this.choices});

  final ChargeGroupKind kind;
  final String label;
  final List<ChargeChoice> choices;
}

String _money(int cents) => '\$${Money(cents).format()}';

/// Builds the grouped charge choices for [meUserId] as of [asOf] (now by
/// default). The Vault section is always present; empty sections are omitted.
List<ChargeGroup> buildChargeGroups(
  HouseholdState state,
  String meUserId, {
  DateTime? asOf,
}) {
  final month = Month.fromInstant(asOf ?? DateTime.now());

  int remaining(SliceConfig cfg) {
    final sm = state.sliceMonth(cfg.sliceId, month);
    final eff = sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
    final spent = sm?.spentCents ?? 0;
    final r = eff - spent;
    return r < 0 ? 0 : r;
  }

  final personal = <ChargeChoice>[];
  final group = <ChargeChoice>[];
  for (final cfg in state.slices.values) {
    if (cfg.isGroup) {
      group.add(ChargeChoice(
        target: SliceCharge(cfg.sliceId),
        label: cfg.name,
        subtitle: '${_money(remaining(cfg))} left',
        kind: ChargeGroupKind.groupSlice,
        supportsShared: false,
      ));
    } else if (cfg.ownerUserId == meUserId) {
      personal.add(ChargeChoice(
        target: SliceCharge(cfg.sliceId),
        label: cfg.name,
        subtitle: '${_money(remaining(cfg))} left',
        kind: ChargeGroupKind.personalSlice,
        supportsShared: true,
      ));
    }
  }
  personal.sort((a, b) => a.label.compareTo(b.label));
  group.sort((a, b) => a.label.compareTo(b.label));

  final quests = <ChargeChoice>[];
  for (final q in state.quests.values) {
    if (q.completed || q.abandoned) continue;
    final owner = q.ownership;
    final mine = owner is SharedParty ||
        (owner is PersonalParty && owner.userId == meUserId);
    if (!mine) continue;
    quests.add(ChargeChoice(
      target: QuestCharge(q.questId),
      label: q.name,
      subtitle: '${_money(q.balanceCents)} / ${_money(q.targetCents)}',
      kind: ChargeGroupKind.quest,
      supportsShared: false,
    ));
  }
  quests.sort((a, b) => a.label.compareTo(b.label));

  final funds = <ChargeChoice>[];
  for (final f in state.emergencyFunds.values) {
    funds.add(ChargeChoice(
      target: EmergencyCharge(f.fundId),
      label: f.name,
      subtitle: '${_money(f.balanceCents)} reserve',
      kind: ChargeGroupKind.emergency,
      supportsShared: false,
    ));
  }
  funds.sort((a, b) => a.label.compareTo(b.label));

  final vault = ChargeChoice(
    target: const VaultCharge(),
    label: 'Vault',
    subtitle: '${_money(state.vaultOf(meUserId))} discretionary',
    kind: ChargeGroupKind.vault,
    supportsShared: true,
  );

  // Open vacations expose one charge target per category, each carrying its
  // remaining sub-budget so the trip stays self-contained.
  final vacation = <ChargeChoice>[];
  for (final v in state.openVacations) {
    for (final c in v.categories) {
      vacation.add(ChargeChoice(
        target: VacationCharge(v.vacationId, c.categoryId),
        label: '${v.name} · ${c.name}',
        subtitle: '${_money(c.leftoverCents)} left',
        kind: ChargeGroupKind.vacation,
        supportsShared: false,
      ));
    }
  }

  return [
    if (personal.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.personalSlice,
        label: 'My budgets',
        choices: personal,
      ),
    if (group.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.groupSlice,
        label: 'Shared budgets',
        choices: group,
      ),
    ChargeGroup(
      kind: ChargeGroupKind.vault,
      label: 'Vault',
      choices: [vault],
    ),
    if (quests.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.quest,
        label: 'Quests',
        choices: quests,
      ),
    if (funds.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.emergency,
        label: 'Emergency funds',
        choices: funds,
      ),
    if (vacation.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.vacation,
        label: 'Vacation',
        choices: vacation,
      ),
  ];
}
