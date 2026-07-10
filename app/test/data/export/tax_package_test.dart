/// Tests the tax-package CSV + receipt naming against a fixture household.
library;

import 'package:lootlog/data/export/tax_package.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/reducer.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:flutter_test/flutter_test.dart';

int _n = 0;
String _id() => 'e${(_n++).toString().padLeft(4, '0')}';
DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d, 18);

const _names = {'u1': 'Alex', 'u2': 'Sam'};

BudgetSliceSet _slice(String id, String name, {bool taxDefault = false}) =>
    BudgetSliceSet(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 1, 1),
      createdAt: _day(2026, 1, 1),
      sliceId: id,
      name: name,
      ownership: const PersonalSlice('u1'),
      limitCents: 100000,
      poolTithePct: 0,
      defaultLeftoverPolicy: const Discretionary(),
      taxDeductibleByDefault: taxDefault,
    );

PurchaseAdded _buy({
  required String id,
  required String slice,
  required int amount,
  String by = 'u1',
  String? merchant,
  bool? tax,
  bool shared = false,
  String? note,
  required DateTime at,
}) =>
    PurchaseAdded(
      eventId: _id(),
      deviceId: 'd',
      userId: by,
      occurredAt: at,
      createdAt: at,
      purchaseId: id,
      target: SliceCharge(slice),
      amountCents: amount,
      merchant: merchant,
      taxDeductible: tax,
      shared: shared,
      note: note,
    );

ReceiptAttached _receipt(String pid, String sha,
        {String mime = 'image/jpeg'}) =>
    ReceiptAttached(
      eventId: _id(),
      deviceId: 'd',
      userId: 'u1',
      occurredAt: _day(2026, 3, 2),
      createdAt: _day(2026, 3, 2),
      purchaseId: pid,
      sha256: sha,
      mimeType: mime,
      sizeBytes: 10,
    );

void main() {
  // A fixture household: a tax-deductible "Work" slice, a non-deductible
  // "Fun" slice, a per-purchase override, receipts, and a purchase in another
  // year that must be excluded.
  final events = <Event>[
    _slice('work', 'Work', taxDefault: true),
    _slice('fun', 'Fun'),
    _buy(
      id: 'p1',
      slice: 'work',
      amount: 12000,
      merchant: 'Office Depot',
      note: 'printer, ink',
      at: _day(2026, 3, 2),
    ),
    _receipt('p1', 'sha_p1a'),
    _receipt('p1', 'sha_p1b', mime: 'application/pdf'),
    // Deductible via per-purchase override on a non-deductible slice.
    _buy(
      id: 'p2',
      slice: 'fun',
      amount: 4500,
      merchant: 'Bookstore',
      tax: true,
      by: 'u2',
      at: _day(2026, 5, 10),
    ),
    // Non-deductible: excluded.
    _buy(id: 'p3', slice: 'fun', amount: 999, at: _day(2026, 6, 1)),
    // Deductible but in a different year: excluded from 2026.
    _buy(
      id: 'p4',
      slice: 'work',
      amount: 8000,
      merchant: 'Prior year',
      at: _day(2025, 12, 15),
    ),
  ];

  final state = reduce(events, asOf: DateTime.utc(2026, 7, 5));

  test('summary.csv lists only the chosen year, deductibles only', () {
    final pkg = buildTaxPackage(state, year: 2026, userNames: _names);
    final lines = pkg.csv.trim().split('\n');
    expect(lines.first,
        'date,user,slice,merchant,amount,shared,note,receipt filename');
    // Two deductible purchases in 2026 -> header + 2 rows.
    expect(lines, hasLength(3));

    // Row order is deterministic (by date): Office Depot (Mar) before Bookstore.
    expect(
      lines[1],
      '2026-03-02,Alex,Work,Office Depot,120.00,no,'
      '"printer, ink",'
      '2026-03-02_Alex_Work_120.00_1.jpg; 2026-03-02_Alex_Work_120.00_2.pdf',
    );
    expect(
      lines[2],
      '2026-05-10,Sam,Fun,Bookstore,45.00,no,,',
    );
  });

  test('receipt files are named date_user_slice_amount_n.ext', () {
    final pkg = buildTaxPackage(state, year: 2026, userNames: _names);
    expect(
      pkg.receipts.map((r) => r.filename).toSet(),
      {
        '2026-03-02_Alex_Work_120.00_1.jpg',
        '2026-03-02_Alex_Work_120.00_2.pdf',
      },
    );
    // Filenames map back to the right blobs.
    final byName = {for (final r in pkg.receipts) r.filename: r.sha256};
    expect(byName['2026-03-02_Alex_Work_120.00_1.jpg'], 'sha_p1a');
    expect(byName['2026-03-02_Alex_Work_120.00_2.pdf'], 'sha_p1b');
  });

  test('an empty year yields just the header', () {
    final pkg = buildTaxPackage(state, year: 2000, userNames: _names);
    expect(pkg.csv.trim(),
        'date,user,slice,merchant,amount,shared,note,receipt filename');
    expect(pkg.receipts, isEmpty);
  });
}
