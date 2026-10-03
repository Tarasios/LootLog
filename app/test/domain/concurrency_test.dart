/// Multi-device convergence: when two devices both settle the same category's
/// month (e.g. the ritual run on a phone AND a desktop before they sync), every
/// device must reduce to the SAME state regardless of the order the duplicate
/// events arrived in. The rule: for one (adult, category, month), the
/// allocation with the latest `occurredAt` wins, `eventId` breaking ties.
library;

import 'package:lootlog/domain/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/time.dart';
import 'package:lootlog/domain/value_types.dart';

DateTime day(int y, int m, int d, [int h = 18]) => DateTime.utc(y, m, d, h);

Event _member(String id) => MemberSet(
  eventId: 'm-$id',
  deviceId: 'd',
  userId: id,
  occurredAt: day(2026, 1, 1),
  createdAt: day(2026, 1, 1),
  memberId: id,
  name: id,
  role: MemberRole.adult,
);

Event _slice() => BudgetSliceSet(
  eventId: 'slice-1',
  deviceId: 'd',
  userId: 'u1',
  occurredAt: day(2026, 1, 1),
  createdAt: day(2026, 1, 1),
  sliceId: 's',
  name: 's',
  ownership: const PersonalSlice('u1'),
  mainCategoryId: null,
  limitCents: 10000,
  poolTithePct: 0,
  defaultLeftoverPolicy: const Discretionary(),
  taxDeductibleByDefault: false,
);

LeftoverAllocated _alloc({
  required String eventId,
  required String device,
  required DateTime at,
  required LeftoverDestination destination,
}) => LeftoverAllocated(
  eventId: eventId,
  deviceId: device,
  userId: 'u1',
  occurredAt: at,
  createdAt: at,
  forUserId: 'u1',
  month: const Month(2026, 1),
  sliceId: 's',
  allocations: [Allocation(destination: destination, amountCents: 10000)],
);

void main() {
  final asOf = day(2026, 2, 20);

  test('duplicate month-close from two devices converges in either order', () {
    // Phone settles first (discretionary), desktop settles later (carry).
    final phone = _alloc(
      eventId: 'a-phone',
      device: 'phone',
      at: day(2026, 2, 2),
      destination: const Discretionary(),
    );
    final desktop = _alloc(
      eventId: 'a-desktop',
      device: 'desktop',
      at: day(2026, 2, 3),
      destination: const CarryInSlice(),
    );

    final base = [_member('u1'), _slice()];
    final s1 = reduce([...base, phone, desktop], asOf: asOf);
    final s2 = reduce([...base, desktop, phone], asOf: asOf);

    // The later ritual (desktop's carry) wins on BOTH devices: the whole
    // leftover carries, nothing lands in the vault.
    for (final s in [s1, s2]) {
      expect(s.vaultCents['u1'] ?? 0, 0);
      final feb = s.sliceMonth('s', const Month(2026, 2))!;
      expect(feb.effectiveLimitCents, 20000);
    }
  });

  test(
    'identical occurredAt falls back to eventId order deterministically',
    () {
      final at = day(2026, 2, 2);
      final a = _alloc(
        eventId: 'a-1',
        device: 'phone',
        at: at,
        destination: const Discretionary(),
      );
      final b = _alloc(
        eventId: 'a-2',
        device: 'desktop',
        at: at,
        destination: const CarryInSlice(),
      );

      final base = [_member('u1'), _slice()];
      final s1 = reduce([...base, a, b], asOf: asOf);
      final s2 = reduce([...base, b, a], asOf: asOf);

      // Highest eventId ('a-2', the carry) wins in both orders.
      for (final s in [s1, s2]) {
        expect(s.vaultCents['u1'] ?? 0, 0);
        expect(
          s.sliceMonth('s', const Month(2026, 2))!.effectiveLimitCents,
          20000,
        );
      }
    },
  );

  test(
    'savings covers and advances from two devices converge in any order',
    () {
      final rules = SettingChanged(
        eventId: 'rules',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: day(2025, 12, 1),
        createdAt: day(2025, 12, 1),
        key: 'savingsRules',
        value: {'fromMonth': '2026-01', 'generalTithePct': 20},
      );
      final gift = GiftReceived(
        eventId: 'gift',
        deviceId: 'd',
        userId: 'u1',
        occurredAt: day(2026, 1, 2),
        createdAt: day(2026, 1, 2),
        forUserId: 'u1',
        amountCents: 50000,
      );
      final buy = PurchaseAdded(
        eventId: 'buy',
        deviceId: 'phone',
        userId: 'u1',
        occurredAt: day(2026, 1, 10),
        createdAt: day(2026, 1, 10),
        purchaseId: 'p',
        target: const SliceCharge('s'),
        amountCents: 16000,
        shared: false,
      );
      final cover = ShortfallCovered(
        eventId: 'cover',
        deviceId: 'phone',
        userId: 'u1',
        occurredAt: day(2026, 1, 10),
        createdAt: day(2026, 1, 10),
        purchaseId: 'p',
        source: const GeneralCover(),
        amountCents: 3000,
      );
      final propose = AllowanceAdvanceProposed(
        eventId: 'adv',
        deviceId: 'phone',
        userId: 'u1',
        occurredAt: day(2026, 1, 10),
        createdAt: day(2026, 1, 10),
        advanceId: 'a',
        byUserId: 'u1',
        sliceId: 's',
        amountCents: 3000,
        months: 2,
      );
      final approve = AllowanceAdvanceApproved(
        eventId: 'ok',
        deviceId: 'desktop',
        userId: 'u2',
        occurredAt: day(2026, 1, 11),
        createdAt: day(2026, 1, 11),
        advanceId: 'a',
        byUserId: 'u2',
      );
      final events = <Event>[
        _member('u1'),
        _member('u2'),
        _slice(),
        rules,
        gift,
        buy,
        cover,
        propose,
        approve,
      ];
      final forward = reduce(events, asOf: asOf);
      final backward = reduce(events.reversed.toList(), asOf: asOf);
      for (final s in [forward, backward]) {
        expect(s.vaultCents['u1'], 50000 - 3000);
        expect(s.advances['a']!.status, WithdrawalStatus.approved);
        expect(s.sliceMonth('s', const Month(2026, 1))!.overspendCents, 0);
        expect(s.sliceMonth('s', const Month(2026, 2))!.trimmedCents, 1500);
      }
      expect(forward.categorySavings, backward.categorySavings);
    },
  );
}
