/// Tests the budget change log (audit) projection: every event surfaces as a
/// human-readable, newest-first entry — including the configuration events the
/// activity feed hides — so the log is a complete, append-only audit trail.
library;

import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/ledger/change_log_model.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _at(int y, int m, int d) => DateTime.utc(y, m, d, 18);

MemberSet _member(String id, String name, MemberRole role) => MemberSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'a1',
      occurredAt: _at(2026, 1, 1),
      createdAt: _at(2026, 1, 1),
      memberId: id,
      name: name,
      role: role,
    );

void main() {
  final names = {'a1': 'Ada', 'a2': 'Ben'};

  test('surfaces every event, config included, newest first', () {
    final events = <Event>[
      _member('a1', 'Ada', MemberRole.adult),
      BudgetSliceSet(
        eventId: _id(),
        deviceId: 'd',
        userId: 'a1',
        occurredAt: _at(2026, 1, 2),
        createdAt: _at(2026, 1, 2),
        sliceId: 's1',
        name: 'Groceries',
        ownership: const GroupSlice(),
        limitCents: 60000,
        poolTithePct: 0,
        defaultLeftoverPolicy: const CarryInSlice(),
        taxDeductibleByDefault: false,
      ),
      SettingChanged(
        eventId: _id(),
        deviceId: 'd',
        userId: 'a1',
        occurredAt: _at(2026, 1, 3),
        createdAt: _at(2026, 1, 3),
        key: 'showNetWorth',
        value: true,
      ),
    ];
    final state = reduce(events);
    final log = buildChangeLog(state, events, userNames: names);

    // One entry per event (none dropped), newest first.
    expect(log, hasLength(3));
    expect(log.first.title, 'Changed a setting');
    expect(log.last.title, contains('Added Ada'));
    expect(log.every((e) => e.author == 'Ada'), isTrue);
  });

  test('a void appears as its own correction entry beside the original', () {
    final events = <Event>[
      PurchaseAdded(
        eventId: _id(),
        deviceId: 'd',
        userId: 'a1',
        occurredAt: _at(2026, 2, 1),
        createdAt: _at(2026, 2, 1),
        purchaseId: 'p1',
        target: const VaultCharge(),
        amountCents: 2500,
        merchant: 'Cafe',
      ),
      PurchaseVoided(
        eventId: _id(),
        deviceId: 'd',
        userId: 'a1',
        occurredAt: _at(2026, 2, 2),
        createdAt: _at(2026, 2, 2),
        purchaseId: 'p1',
      ),
    ];
    final state = reduce(events);
    final log = buildChangeLog(state, events, userNames: names);

    expect(log, hasLength(2));
    expect(log.first.kind, ChangeLogKind.correction);
    final purchase =
        log.firstWhere((e) => e.kind == ChangeLogKind.purchase);
    expect(purchase.amountCents, -2500);
    expect(purchase.detail, contains('Cafe'));
  });

  test('unknown authors degrade to "Someone" rather than crashing', () {
    final events = <Event>[_member('ghost', 'Casper', MemberRole.pet)];
    final state = reduce(events);
    final log = buildChangeLog(state, events, userNames: const {});
    expect(log.single.author, 'Someone');
  });
}
