/// Shared, deterministic charge-group fixtures for widget and golden tests.
library;

import 'package:duobudget/domain/value_types.dart';
import 'package:duobudget/features/entry/charge_choice.dart';

/// A representative set of grouped charge choices covering every kind, so the
/// golden captures the visual grouping and distinct tints.
List<ChargeGroup> sampleChargeGroups() => const [
      ChargeGroup(
        kind: ChargeGroupKind.personalSlice,
        label: 'My budgets',
        choices: [
          ChargeChoice(
            target: SliceCharge('s-food'),
            label: 'Food',
            subtitle: '\$120.00 left',
            kind: ChargeGroupKind.personalSlice,
            supportsShared: true,
          ),
          ChargeChoice(
            target: SliceCharge('s-fun'),
            label: 'Fun',
            subtitle: '\$40.00 left',
            kind: ChargeGroupKind.personalSlice,
            supportsShared: true,
          ),
        ],
      ),
      ChargeGroup(
        kind: ChargeGroupKind.groupSlice,
        label: 'Shared budgets',
        choices: [
          ChargeChoice(
            target: SliceCharge('s-groceries'),
            label: 'Groceries',
            subtitle: '\$210.00 left',
            kind: ChargeGroupKind.groupSlice,
            supportsShared: false,
          ),
        ],
      ),
      ChargeGroup(
        kind: ChargeGroupKind.vault,
        label: 'Vault',
        choices: [
          ChargeChoice(
            target: VaultCharge(),
            label: 'Vault',
            subtitle: '\$88.50 discretionary',
            kind: ChargeGroupKind.vault,
            supportsShared: true,
          ),
        ],
      ),
      ChargeGroup(
        kind: ChargeGroupKind.quest,
        label: 'Quests',
        choices: [
          ChargeChoice(
            target: QuestCharge('q-canoe'),
            label: 'Canoe',
            subtitle: '\$300.00 / \$1300.00',
            kind: ChargeGroupKind.quest,
            supportsShared: false,
          ),
        ],
      ),
      ChargeGroup(
        kind: ChargeGroupKind.emergency,
        label: 'Emergency funds',
        choices: [
          ChargeChoice(
            target: EmergencyCharge('e-vet'),
            label: 'Vet fund',
            subtitle: '\$500.00 reserve',
            kind: ChargeGroupKind.emergency,
            supportsShared: false,
          ),
        ],
      ),
    ];
