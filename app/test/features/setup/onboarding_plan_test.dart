/// Tests the pure onboarding model: collected inputs → the exact event list the
/// first-run wizard appends, replayed through the reducer to prove the resulting
/// household is the one the party described.
library;

import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/setup/onboarding_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// A deterministic id generator so event ids (and entity ids) are stable and
/// sort in emission order.
String Function() _counter() {
  var n = 0;
  return () => 'e${(n++).toString().padLeft(4, '0')}';
}

final _now = DateTime.utc(2026, 7, 9, 18);
const _month = Month(2026, 7);

OnboardingPlan _plan(OnboardingInput input) => buildOnboardingEvents(
      input,
      deviceId: 'device-1',
      startMonth: _month,
      now: _now,
      idGen: _counter(),
    );

void main() {
  group('buildOnboardingEvents', () {
    test('single-adult party writes member, income and no share table', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Robin'),
        ],
        meLocalId: 'a1',
        defaultIncomeByAdult: {'a1': 500000},
      ));

      final members = plan.events.whereType<MemberSet>().toList();
      expect(members, hasLength(1));
      expect(members.single.name, 'Robin');
      expect(members.single.role, MemberRole.adult);

      final incomes = plan.events.whereType<DefaultIncomeSet>().toList();
      expect(incomes, hasLength(1));
      expect(incomes.single.forUserId, 'a1');
      expect(incomes.single.amountCents, 500000);
      expect(incomes.single.effectiveFromMonth, _month);

      // No share table for a single-adult household.
      expect(plan.events.whereType<GroupShareSet>(), isEmpty);

      // Device pointer names the sole adult on both legacy profiles.
      expect(plan.localSetup.meUserId, 'a1');
      expect(plan.localSetup.me.name, 'Robin');
      expect(plan.localSetup.partner.userId, 'a1');
    });

    test('zero income is written explicitly, not skipped', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Robin'),
        ],
        meLocalId: 'a1',
        defaultIncomeByAdult: {'a1': 0},
      ));
      final income = plan.events.whereType<DefaultIncomeSet>().single;
      expect(income.amountCents, 0);
    });

    test('members are ordered and typed adults → dependents → pets', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
          DraftMember(localId: 'a2', role: DraftRole.adult, name: 'Ben'),
          DraftMember(localId: 'd1', role: DraftRole.dependent, name: 'Cy'),
          DraftMember(
            localId: 'p1',
            role: DraftRole.pet,
            name: 'Rex',
            descriptionText: 'a very good dog',
          ),
        ],
        meLocalId: 'a1',
      ));

      final memberEvents = plan.events.whereType<MemberSet>().toList();
      expect(
        memberEvents.map((m) => m.role).toList(),
        [MemberRole.adult, MemberRole.adult, MemberRole.dependent, MemberRole.pet],
      );
      final rex = memberEvents.last;
      expect(rex.descriptionText, 'a very good dog');
    });

    test('two adults get an even share table summing to 1000 permille', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
          DraftMember(localId: 'a2', role: DraftRole.adult, name: 'Ben'),
        ],
        meLocalId: 'a1',
      ));
      final shares = plan.events.whereType<GroupShareSet>().single;
      expect(shares.shares, {'a1': 500, 'a2': 500});
      expect(shares.shares.values.reduce((a, b) => a + b), 1000);
    });

    test('three adults split with remainder cents to the earliest', () {
      expect(evenShares(['a', 'b', 'c']), {'a': 334, 'b': 333, 'c': 333});
      expect(
        evenShares(['a', 'b', 'c']).values.reduce((a, b) => a + b),
        1000,
      );
    });

    test('a custom share table is written verbatim', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
          DraftMember(localId: 'a2', role: DraftRole.adult, name: 'Ben'),
        ],
        meLocalId: 'a1',
        shares: {'a1': 700, 'a2': 300},
      ));
      expect(plan.events.whereType<GroupShareSet>().single.shares,
          {'a1': 700, 'a2': 300});
    });

    test('accounts write config + balance and enable the net-worth screen', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
        ],
        meLocalId: 'a1',
        accounts: [
          DraftAccount(
            name: 'Rainy day',
            kind: AccountKind.savings,
            balanceCents: 1000000,
            aprBps: 400,
            accrualCadence: AccountCadence.monthly,
          ),
          DraftAccount(
            name: 'Visa',
            kind: AccountKind.debt,
            balanceCents: 250000,
            aprBps: 1999,
            minPaymentCents: 5000,
          ),
        ],
      ));

      final accounts = plan.events.whereType<TrackedAccountSet>().toList();
      expect(accounts, hasLength(2));
      final debt = accounts.firstWhere((a) => a.kind == AccountKind.debt);
      expect(debt.minPaymentCents, 5000);

      final balances = plan.events.whereType<AccountBalanceRecorded>().toList();
      expect(balances, hasLength(2));

      final flag = plan.events
          .whereType<SettingChanged>()
          .singleWhere((s) => s.key == 'showNetWorth');
      expect(flag.value, true);

      // The debt's minimum payment surfaces as a recurring expense in state.
      final state = reduce(plan.events);
      expect(state.netWorth.show, isTrue);
    });

    test('fixed expenses: group ones come first and split shared', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
        ],
        meLocalId: 'a1',
        fixedExpenses: [
          DraftFixedExpense(
            name: 'Netflix',
            shared: false,
            ownerLocalId: 'a1',
            amountCents: 1599,
          ),
          DraftFixedExpense(name: 'Rent', shared: true, amountCents: 200000),
          DraftFixedExpense(
            name: 'Domain',
            shared: true,
            amountCents: 1200,
            cadence: RecurringCadence.annual,
            dueMonth: 2,
            dueDay: 10,
          ),
        ],
      ));

      final expenses = plan.events.whereType<RecurringExpenseSet>().toList();
      expect(expenses.map((e) => e.name).toList(), ['Rent', 'Domain', 'Netflix']);
      expect(expenses[0].ownership, const SharedParty());
      expect(expenses[2].ownership, const PersonalParty('a1'));
      final annual =
          expenses.firstWhere((e) => e.cadence == RecurringCadence.annual);
      expect(annual.dueMonth, 2);
      expect(annual.dueDay, 10);
      expect(expenses.every((e) => e.kind == RecurringKind.fixed), isTrue);
    });

    test('budget: group categories precede personal and carry main category',
        () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
        ],
        meLocalId: 'a1',
        categories: [
          DraftCategory(
            name: 'Fun',
            limitCents: 20000,
            group: false,
            ownerLocalId: 'a1',
            mainCategoryId: 'entertainment',
          ),
          DraftCategory(
            name: 'Groceries',
            limitCents: 60000,
            group: true,
            mainCategoryId: 'food',
          ),
        ],
      ));

      final slices = plan.events.whereType<BudgetSliceSet>().toList();
      expect(slices.map((s) => s.name).toList(), ['Groceries', 'Fun']);
      expect(slices[0].ownership, const GroupSlice());
      expect(slices[1].ownership, const PersonalSlice('a1'));
      expect(slices[1].mainCategoryId, 'entertainment');
    });

    test('the optional first goal becomes a QuestSet with description', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
        ],
        meLocalId: 'a1',
        firstQuest: DraftQuest(
          name: 'Canoe',
          targetCents: 130000,
          shared: true,
          mainCategoryId: 'savings',
          descriptionText: 'a red cedar canoe',
        ),
      ));
      final quest = plan.events.whereType<QuestSet>().single;
      expect(quest.name, 'Canoe');
      expect(quest.targetCents, 130000);
      expect(quest.ownership, const SharedParty());
      expect(quest.mainCategoryId, 'savings');
      expect(quest.descriptionText, 'a red cedar canoe');
    });

    test('no goal → no QuestSet', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
        ],
        meLocalId: 'a1',
      ));
      expect(plan.events.whereType<QuestSet>(), isEmpty);
    });

    test('a full party replays through the reducer into the described state',
        () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
          DraftMember(localId: 'a2', role: DraftRole.adult, name: 'Ben'),
          DraftMember(localId: 'p1', role: DraftRole.pet, name: 'Rex'),
        ],
        meLocalId: 'a1',
        defaultIncomeByAdult: {'a1': 400000, 'a2': 300000},
        categories: [
          DraftCategory(
            name: 'Groceries',
            limitCents: 60000,
            group: true,
            mainCategoryId: 'food',
          ),
          DraftCategory(
            name: "Ada's fun",
            limitCents: 15000,
            group: false,
            ownerLocalId: 'a1',
            mainCategoryId: 'entertainment',
          ),
        ],
        firstQuest: DraftQuest(
          name: 'Vacation',
          targetCents: 200000,
          shared: true,
          mainCategoryId: 'savings',
        ),
      ));

      final state = reduce(plan.events);
      expect(state.adultIds, {'a1', 'a2'});
      expect(state.members['p1']!.role, MemberRole.pet);
      expect(state.incomeFor('a1', _month), 400000);
      expect(state.incomeFor('a2', _month), 300000);
      expect(state.slices.values.where((s) => s.isGroup), hasLength(1));
      expect(state.quests.values.single.name, 'Vacation');
    });

    test('rejects a party with no adults', () {
      expect(
        () => _plan(const OnboardingInput(
          members: [
            DraftMember(localId: 'p1', role: DraftRole.pet, name: 'Rex'),
          ],
          meLocalId: 'p1',
        )),
        throwsArgumentError,
      );
    });

    test('rejects a me pointer that is not an adult', () {
      expect(
        () => _plan(const OnboardingInput(
          members: [
            DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
            DraftMember(localId: 'p1', role: DraftRole.pet, name: 'Rex'),
          ],
          meLocalId: 'p1',
        )),
        throwsArgumentError,
      );
    });

    test('every event carries the device id and me as author', () {
      final plan = _plan(const OnboardingInput(
        members: [
          DraftMember(localId: 'a1', role: DraftRole.adult, name: 'Ada'),
          DraftMember(localId: 'a2', role: DraftRole.adult, name: 'Ben'),
        ],
        meLocalId: 'a2',
      ));
      expect(plan.events.every((e) => e.deviceId == 'device-1'), isTrue);
      expect(plan.events.every((e) => e.userId == 'a2'), isTrue);
    });
  });
}
