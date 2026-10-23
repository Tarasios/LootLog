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
import '../../ui/glossary.dart';

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
  const ChargeGroup({
    required this.kind,
    required this.label,
    required this.choices,
  });

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
  bool isAdventure = false,
  DateTime? asOf,
}) {
  final month = Month.fromInstant(asOf ?? DateTime.now());

  int remaining(SliceConfig sliceConfig) {
    final sliceMonth = state.sliceMonth(sliceConfig.sliceId, month);
    final effectiveLimit =
        sliceMonth?.effectiveLimitCents ?? sliceConfig.baseEffectiveLimitCents;
    final spent = sliceMonth?.spentCents ?? 0;
    final leftover = effectiveLimit - spent;
    return leftover < 0 ? 0 : leftover;
  }

  final personal = <ChargeChoice>[];
  final group = <ChargeChoice>[];
  for (final sliceConfig in state.slices.values) {
    if (sliceConfig.isGroup) {
      group.add(
        ChargeChoice(
          target: SliceCharge(sliceConfig.sliceId),
          label: sliceConfig.name,
          subtitle: '${_money(remaining(sliceConfig))} left',
          kind: ChargeGroupKind.groupSlice,
          supportsShared: false,
        ),
      );
    } else if (sliceConfig.ownerUserId == meUserId) {
      personal.add(
        ChargeChoice(
          target: SliceCharge(sliceConfig.sliceId),
          label: sliceConfig.name,
          subtitle: '${_money(remaining(sliceConfig))} left',
          kind: ChargeGroupKind.personalSlice,
          supportsShared: true,
        ),
      );
    }
  }
  personal.sort((first, second) => first.label.compareTo(second.label));
  group.sort((first, second) => first.label.compareTo(second.label));

  final quests = <ChargeChoice>[];
  for (final quest in state.quests.values) {
    if (quest.completed || quest.abandoned) continue;
    final owner = quest.ownership;
    final mine =
        owner is SharedParty ||
        (owner is PersonalParty && owner.userId == meUserId);
    if (!mine) continue;
    quests.add(
      ChargeChoice(
        target: QuestCharge(quest.questId),
        label: quest.name,
        subtitle:
            '${_money(quest.balanceCents)} / ${_money(quest.targetCents)}',
        kind: ChargeGroupKind.quest,
        supportsShared: false,
      ),
    );
  }
  quests.sort((first, second) => first.label.compareTo(second.label));

  final funds = <ChargeChoice>[];
  for (final fund in state.emergencyFunds.values) {
    funds.add(
      ChargeChoice(
        target: EmergencyCharge(fund.fundId),
        label: fund.name,
        subtitle: '${_money(fund.balanceCents)} reserve',
        kind: ChargeGroupKind.emergency,
        supportsShared: false,
      ),
    );
  }
  funds.sort((first, second) => first.label.compareTo(second.label));

  final vaultTitle = Glossary.cap(
    Glossary.vaultLabel(
      isAdventure: isAdventure,
      savingsRules: state.savingsRules != null,
    ),
  );
  final vault = ChargeChoice(
    target: const VaultCharge(),
    label: vaultTitle,
    subtitle: '${_money(state.vaultOf(meUserId))} available',
    kind: ChargeGroupKind.vault,
    supportsShared: true,
  );

  // Open vacations expose one charge target per category, each carrying its
  // remaining sub-budget so the trip stays self-contained.
  final vacationChoices = <ChargeChoice>[];
  for (final openVacation in state.openVacations) {
    for (final category in openVacation.categories) {
      vacationChoices.add(
        ChargeChoice(
          target: VacationCharge(openVacation.vacationId, category.categoryId),
          label: '${openVacation.name} · ${category.name}',
          subtitle: '${_money(category.leftoverCents)} left',
          kind: ChargeGroupKind.vacation,
          supportsShared: false,
        ),
      );
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
      label: vaultTitle,
      choices: [vault],
    ),
    if (quests.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.quest,
        label: isAdventure ? 'Quests' : 'Savings goals',
        choices: quests,
      ),
    if (funds.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.emergency,
        label: 'Emergency funds',
        choices: funds,
      ),
    if (vacationChoices.isNotEmpty)
      ChargeGroup(
        kind: ChargeGroupKind.vacation,
        label: 'Vacation',
        choices: vacationChoices,
      ),
  ];
}
