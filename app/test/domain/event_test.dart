import 'dart:convert';

import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/ids.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _occ = DateTime.utc(2026, 3, 15, 20);
final DateTime _cre = DateTime.utc(2026, 3, 15, 20, 1);

void main() {
  group('envelope', () {
    test('occurredMonth is derived in the household timezone', () {
      final e = PurchaseAdded(
        eventId: 'e1',
        deviceId: 'd1',
        userId: 'u1',
        // 2026-03-01 07:30 UTC == Feb 28 23:30 PST.
        occurredAt: DateTime.utc(2026, 3, 1, 7, 30),
        createdAt: _cre,
        purchaseId: 'p1',
        target: const SliceCharge('s1'),
        amountCents: 100,
      );
      expect(e.occurredMonth, const Month(2026, 2));
    });

    test('generated eventId is a UUIDv7', () {
      final id = uuidv7(millisSinceEpoch: 1000);
      expect(
        id,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
      );
    });
  });

  group('JSON round-trip', () {
    final samples = <Event>[
      PurchaseAdded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p1',
        target: const SliceCharge('s1'),
        amountCents: 1299,
        shared: true,
        merchant: 'Store',
        taxDeductible: true,
        note: 'lunch',
      ),
      PurchaseAdded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p2',
        target: const VaultCharge(),
        amountCents: 500,
      ),
      PurchaseAdded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p3',
        target: const QuestCharge('q1'),
        amountCents: 50000,
      ),
      PurchaseAdded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p4',
        target: const EmergencyCharge('f1'),
        amountCents: 8000,
      ),
      PurchaseVoided(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p1',
      ),
      BudgetSliceSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        sliceId: 's1',
        name: 'Groceries',
        ownership: const GroupSlice(),
        limitCents: 60000,
        poolTithePct: 10,
        defaultLeftoverPolicy: const Discretionary(),
        taxDeductibleByDefault: false,
        emergencyContribution:
            const EmergencyContribution(fundId: 'f1', amountCents: 5000),
        petId: 'pet1',
      ),
      BudgetSliceSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        sliceId: 's2',
        name: 'Hobbies',
        ownership: const PersonalSlice('u1'),
        mainCategoryId: 'entertainment',
        limitCents: 20000,
        poolTithePct: 25,
        defaultLeftoverPolicy: const CarryInSlice(),
        taxDeductibleByDefault: true,
      ),
      MainCategorySet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        id: 'entertainment',
        name: 'Fun & Games',
        colorArgb: 0xFF59A14F,
        sortOrder: 4,
      ),
      RecurringExpenseSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        expenseId: 'r1',
        name: 'Rent',
        ownership: const SharedParty(),
        kind: RecurringKind.fixed,
        amountCents: 200000,
        startMonth: const Month(2026, 1),
        endMonth: const Month(2026, 12),
      ),
      VariableExpenseRecorded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        expenseId: 'r2',
        month: const Month(2026, 3),
        actualCents: 8500,
      ),
      IncomeSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        forUserId: 'u1',
        amountCents: 400000,
        month: const Month(2026, 3),
      ),
      QuestSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        questId: 'q1',
        name: 'Canoe',
        targetCents: 130000,
        ownership: const SharedParty(),
        sliceHint: 's2',
        customSpriteSha256: 'abc',
      ),
      QuestAbandoned(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        questId: 'q1',
      ),
      LeftoverAllocated(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        forUserId: 'u1',
        month: const Month(2026, 3),
        sliceId: 's2',
        allocations: const [
          Allocation(destination: CarryInSlice(), amountCents: 1000),
          Allocation(destination: QuestDestination('q1'), amountCents: 2000),
          Allocation(destination: Discretionary(), amountCents: 500),
        ],
      ),
      GiftReceived(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        forUserId: 'u2',
        amountCents: 5000,
        note: 'birthday',
      ),
      PoolContributionMade(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        fromUserId: 'u1',
        amountCents: 10000,
      ),
      PoolWithdrawalProposed(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        proposalId: 'w1',
        byUserId: 'u1',
        amountCents: 25000,
        purpose: 'new tires',
        destination: const UserVaultDestination('u1'),
      ),
      PoolWithdrawalApproved(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u2',
        occurredAt: _occ,
        createdAt: _cre,
        proposalId: 'w1',
        byUserId: 'u2',
      ),
      PoolWithdrawalCancelled(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        proposalId: 'w1',
      ),
      TaxRefundRecorded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        amountCents: 120000,
        note: '2025 refund',
      ),
      EmergencyFundSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        fundId: 'f1',
        name: 'Vet fund',
        petId: 'pet1',
      ),
      PetSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        petId: 'pet1',
        name: 'Mochi',
        customSpriteSha256: 'sha',
      ),
      MemberSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        memberId: 'm1',
        name: 'Alex',
        role: MemberRole.adult,
        active: true,
        customSpriteSha256: 'sha',
        descriptionText: 'A weary but hopeful ranger.',
      ),
      MemberSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        memberId: 'm2',
        name: 'Robin',
        role: MemberRole.dependent,
        active: false,
      ),
      GroupShareSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        month: const Month(2026, 3),
        shares: const {'u1': 600, 'u2': 400},
      ),
      GoalSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        targetCents: 1000000,
      ),
      ReceiptAttached(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p1',
        sha256: 'deadbeef',
        mimeType: 'image/jpeg',
        sizeBytes: 12345,
      ),
      ReceiptDetached(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p1',
        sha256: 'deadbeef',
      ),
      AccountBalanceRecorded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        accountId: 'a1',
        accountName: 'Chequing',
        kind: AccountKind.cash,
        balanceCents: 340000,
      ),
      SettingChanged(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        key: 'dissolutionTithePct',
        value: 15,
      ),
      CosmeticSet(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        key: 'theme',
        value: 'adventure',
      ),
    ];

    for (final sample in samples) {
      test('${sample.type} survives toJson/fromJson', () {
        final json = sample.toJson();
        final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
        final restored = Event.fromJson(decoded);
        expect(restored.runtimeType, sample.runtimeType);
        expect(restored.toJson(), equals(sample.toJson()));
      });
    }
  });

  test('shared flag is rejected for quest and emergency targets', () {
    expect(
      () => PurchaseAdded(
        eventId: 'e',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: _occ,
        createdAt: _cre,
        purchaseId: 'p',
        target: const QuestCharge('q1'),
        amountCents: 100,
        shared: true,
      ),
      throwsArgumentError,
    );
  });
}
