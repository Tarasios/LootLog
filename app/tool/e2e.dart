// ignore_for_file: avoid_print
/// End-to-end convergence harness for LootLog's multi-hub LAN sync.
///
/// Stands up three real, file-backed instances over loopback HTTP — two desktops
/// (each hosting a hub) and a third client paired to both — and drives the full
/// list of convergence scenarios from the release checklist against the real
/// `HubServer`, `SyncClient`, reducer, blob store, receipt-library projector,
/// tax-package exporter and file-fallback import/export. Every "…identically
/// everywhere" claim is checked by comparing the reduced `HouseholdState`
/// snapshot across all instances; correctness (not just consistency) is pinned
/// with absolute assertions on values the harness fully controls.
///
/// Run via `tool/e2e.sh`. Exits nonzero if any assertion fails.
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:duobudget/data/blobs/blob_store.dart';
import 'package:duobudget/data/db/database.dart';
import 'package:duobudget/data/export/event_export.dart';
import 'package:duobudget/data/export/tax_package.dart';
import 'package:duobudget/data/library/receipt_library.dart';
import 'package:duobudget/data/sync/hub_server.dart';
import 'package:duobudget/data/sync/sync_client.dart';
import 'package:duobudget/domain/event.dart';
import 'package:duobudget/domain/ids.dart';
import 'package:duobudget/domain/reducer.dart';
import 'package:duobudget/domain/state.dart';
import 'package:duobudget/domain/time.dart';
import 'package:duobudget/domain/value_types.dart';

// ---- household fixture ------------------------------------------------------

const alice = 'user-alice';
const bob = 'user-bob';
const userNames = {alice: 'Alice', bob: 'Bob'};

// A fixed read-time so grace-period resolution is deterministic: July 2026's
// spoils grace (7 days past month end) has lapsed, and so has June's.
final asOf = DateTime.utc(2026, 8, 20);

// Vancouver is UTC-7 in summer; 18:00Z is 11:00 local, safely inside the day.
DateTime july(int day) => DateTime.utc(2026, 7, day, 18);
DateTime june(int day) => DateTime.utc(2026, 6, day, 18);
final julyMonth = Month(2026, 7);
final juneMonth = Month(2026, 6);

// slice / quest / fund ids
const sGroceries = 'slice-groceries';
const sAliceFun = 'slice-alice-fun';
const sBobFun = 'slice-bob-fun';
const qCanoe = 'quest-canoe';
const qJacket = 'quest-jacket';
const efHealth = 'fund-health';

int _failures = 0;

void check(bool cond, String msg) {
  if (cond) {
    print('  ✓ $msg');
  } else {
    _failures++;
    print('  ✗ FAIL: $msg');
  }
}

void checkEq(Object? got, Object? want, String msg) =>
    check(got == want, '$msg (got $got, want $want)');

/// One device: its store, blob dir, optional hosted hub, and client.
class Node {
  Node(this.label, this.dir, this.meUserId)
      : db = AppDatabase(NativeDatabase(File('${dir.path}/db.sqlite'))),
        blobs = BlobStore(Directory('${dir.path}/blobs')) {
    client = SyncClient(db: db, blobs: blobs, deviceName: label);
  }

  final String label;
  final Directory dir;
  final String meUserId;
  final AppDatabase db;
  final BlobStore blobs;
  late final SyncClient client;
  HubServer? hub;
  HttpServer? httpServer;
  String? hubUrl;
  final String deviceId = uuidv7();

  Future<void> author(Iterable<Event> events) =>
      db.eventsDao.appendEvents(events);

  Future<HouseholdState> reduced() async =>
      reduce(await db.eventsDao.allEvents(), asOf: asOf);

  Future<String> snapshot() async =>
      jsonEncode((await reduced()).debugSnapshot());

  Future<void> startHub(String hubId, String secret) async {
    final h = HubServer(db: db, blobs: blobs, hubId: hubId, pairingSecret: secret);
    final s = await h.serve(port: 0);
    hub = h;
    httpServer = s;
    hubUrl = 'http://127.0.0.1:${s.port}';
  }

  Future<void> close() async {
    client.close();
    await httpServer?.close(force: true);
    await db.close();
  }
}

// ---- envelope helpers -------------------------------------------------------

PurchaseAdded purchase(
  Node n,
  String userId,
  String purchaseId,
  ChargeTarget target,
  int amountCents,
  DateTime at, {
  bool shared = false,
  String? merchant,
  bool? taxDeductible,
  String? note,
}) =>
    PurchaseAdded(
      eventId: uuidv7(),
      deviceId: n.deviceId,
      userId: userId,
      occurredAt: at,
      createdAt: at,
      purchaseId: purchaseId,
      target: target,
      amountCents: amountCents,
      shared: shared,
      merchant: merchant,
      taxDeductible: taxDeductible,
      note: note,
    );

BudgetSliceSet slice(
  Node n,
  String sliceId,
  String name,
  SliceOwnership ownership,
  int limitCents, {
  int poolTithePct = 0,
  LeftoverDestination policy = const CarryInSlice(),
  bool taxDeductibleByDefault = false,
  EmergencyContribution? emergencyContribution,
  DateTime? createdAt,
}) =>
    BudgetSliceSet(
      eventId: uuidv7(),
      deviceId: n.deviceId,
      userId: alice,
      occurredAt: createdAt ?? july(1),
      createdAt: createdAt ?? july(1),
      sliceId: sliceId,
      name: name,
      ownership: ownership,
      limitCents: limitCents,
      poolTithePct: poolTithePct,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: taxDeductibleByDefault,
      emergencyContribution: emergencyContribution,
    );

// ---- main -------------------------------------------------------------------

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('duobudget-e2e-');
  print('LootLog e2e — scratch: ${root.path}\n');

  final a = Node('desktop-A', await _sub(root, 'A'), alice);
  final b = Node('desktop-B', await _sub(root, 'B'), bob);
  final c = Node('phone-C', await _sub(root, 'C'), alice);

  final nodes = [a, b, c];

  try {
    // Two desktops, each hosting a hub.
    await a.startHub('hub-A', 'secret-A');
    await b.startHub('hub-B', 'secret-B');

    // Topology: desktops cross-pair (A<->hubB, B<->hubA) and the phone pairs
    // both hubs. Every device is a client; every desktop is also a hub.
    print('== pairing ==');
    await a.client.pair(b.hubUrl!, 'secret-B');
    await b.client.pair(a.hubUrl!, 'secret-A');
    await c.client.pair(a.hubUrl!, 'secret-A');
    await c.client.pair(b.hubUrl!, 'secret-B');
    check(true, 'all devices paired to their hubs');

    // Seed the household config on A (offline), then let it gossip out below.
    await a.author([
      slice(a, sGroceries, 'Groceries', const GroupSlice(), 60000,
          policy: const Discretionary()),
      slice(a, sAliceFun, 'Alice Fun', const PersonalSlice(alice), 30000,
          poolTithePct: 10,
          emergencyContribution:
              const EmergencyContribution(fundId: efHealth, amountCents: 5000)),
      // Bob-Fun exists a month early so the retroactive June purchase has a
      // slice-month to land in; Alice-Fun starts in July so its emergency
      // contribution has accrued only 5000 by the July ransack.
      slice(a, sBobFun, 'Bob Fun', const PersonalSlice(bob), 30000,
          poolTithePct: 20, createdAt: june(1)),
      EmergencyFundSet(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: alice,
        occurredAt: july(1),
        createdAt: july(1),
        fundId: efHealth,
        name: 'Health Reserve',
      ),
      QuestSet(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: alice,
        occurredAt: july(1),
        createdAt: july(1),
        questId: qCanoe,
        name: 'Canoe',
        targetCents: 130000,
        ownership: const SharedParty(),
      ),
      QuestSet(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: alice,
        occurredAt: july(1),
        createdAt: july(1),
        questId: qJacket,
        name: 'Jacket',
        targetCents: 50000,
        ownership: const PersonalParty(alice),
      ),
    ]);

    // --- Scenario 1: offline entries on different devices converge ----------
    print('\n== 1. offline entries converge ==');
    // Each device records something while "offline" (before this sync round).
    await a.author([
      purchase(a, alice, 'p-shared', const SliceCharge(sAliceFun), 4000, july(3),
          shared: true, merchant: 'Cafe'),
    ]);
    await b.author([
      purchase(b, bob, 'p-group', const SliceCharge(sGroceries), 10000, july(6),
          merchant: 'Market'),
    ]);
    await c.author([
      purchase(c, alice, 'p-retro', const SliceCharge(sBobFun), 5000, june(20),
          merchant: 'LastMonth'),
    ]);
    await convergeAll(nodes);
    await assertConverged(nodes, 'offline entries from all three devices');

    // --- Scenario 2: a shared purchase splits correctly everywhere ----------
    print('\n== 2. shared purchase split ==');
    for (final n in nodes) {
      final st = await n.reduced();
      final sm = st.sliceMonth(sAliceFun, julyMonth)!;
      // 4000 shared, designated half (2000) hits the purchaser's slice.
      check(sm.spentCents == 2000,
          '${n.label}: Alice-Fun July spent = ${sm.spentCents} (want 2000)');
      // The other half (2000) is drawn from the partner's vault.
      final st2 = st.debugSnapshot()['vaults'] as Map;
      check(st2[bob] == 0 || (st2[bob] as int) <= 0,
          '${n.label}: Bob vault not credited by the shared half');
    }

    // --- Scenario 3: a group-slice purchase appears jointly -----------------
    print('\n== 3. group-slice purchase appears jointly ==');
    for (final n in nodes) {
      final st = await n.reduced();
      final sm = st.sliceMonth(sGroceries, julyMonth)!;
      check(sm.isGroup, '${n.label}: Groceries is a group slice');
      checkEq(sm.spentCents, 10000, '${n.label}: Groceries July joint spend');
      final p = st.purchases['p-group']!;
      check(!p.shared, '${n.label}: group purchase carries no per-user split');
    }

    // --- Scenario 4: retroactive last-month purchase changes spoils ---------
    print('\n== 4. retroactive last-month purchase ==');
    for (final n in nodes) {
      final st = await n.reduced();
      final smJun = st.sliceMonth(sBobFun, juneMonth)!;
      // Bob-Fun June limit 30000, retro spend 5000 -> leftover 25000.
      checkEq(smJun.spentCents, 5000, '${n.label}: Bob-Fun June spend');
      checkEq(smJun.leftoverCents, 25000, '${n.label}: Bob-Fun June leftover');
    }

    // --- Scenario 5: spoils allocated on one device, identical elsewhere ----
    print('\n== 5. spoils allocation converges ==');
    // Alice allocates her Alice-Fun July leftover on desktop B.
    // eff = base 25000 (limit 30000 - emergency 5000), spent 2000 -> leftover
    // 23000. Attack Jacket 10000 (untithed) + 13000 discretionary (10% tithe ->
    // 1300 to the chest, 11700 to Alice's vault).
    await b.author([
      LeftoverAllocated(
        eventId: uuidv7(),
        deviceId: b.deviceId,
        userId: alice,
        occurredAt: july(31),
        createdAt: july(31),
        forUserId: alice,
        month: julyMonth,
        sliceId: sAliceFun,
        allocations: const [
          Allocation(destination: QuestDestination(qJacket), amountCents: 10000),
          Allocation(destination: Discretionary(), amountCents: 13000),
        ],
      ),
    ]);
    await convergeAll(nodes);
    await assertConverged(nodes, 'spoils allocation');
    for (final n in nodes) {
      final st = await n.reduced();
      checkEq(st.quests[qJacket]!.balanceCents, 10000,
          '${n.label}: Jacket quest funded by spoils');
    }

    // --- Scenario 6: withdrawal proposed on one, approved on another --------
    print('\n== 6. pool withdrawal + self-approval rejection ==');
    // Give the war chest something to draw on via a pool contribution first.
    await a.author([
      GiftReceived(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: bob,
        occurredAt: july(2),
        createdAt: july(2),
        forUserId: bob,
        amountCents: 40000,
        note: 'seed',
      ),
      PoolContributionMade(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: bob,
        occurredAt: july(2),
        createdAt: july(2),
        fromUserId: bob,
        amountCents: 30000,
      ),
    ]);
    // Bob proposes on desktop B; a self-approval by Bob must be rejected.
    await b.author([
      PoolWithdrawalProposed(
        eventId: uuidv7(),
        deviceId: b.deviceId,
        userId: bob,
        occurredAt: july(10),
        createdAt: july(10),
        proposalId: 'w-1',
        byUserId: bob,
        amountCents: 10000,
        purpose: 'new tent',
        destination: const UserVaultDestination(bob),
      ),
      PoolWithdrawalApproved(
        eventId: uuidv7(),
        deviceId: b.deviceId,
        userId: bob,
        occurredAt: july(11),
        createdAt: july(11),
        proposalId: 'w-1',
        byUserId: bob, // self-approval — reducer must ignore this
      ),
    ]);
    await convergeAll(nodes);
    for (final n in nodes) {
      final st = await n.reduced();
      checkEq(st.withdrawals['w-1']!.status, WithdrawalStatus.pending,
          '${n.label}: self-approval leaves proposal pending');
    }
    // Alice approves on desktop A; now it settles everywhere.
    await a.author([
      PoolWithdrawalApproved(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: alice,
        occurredAt: july(12),
        createdAt: july(12),
        proposalId: 'w-1',
        byUserId: alice,
      ),
    ]);
    await convergeAll(nodes);
    await assertConverged(nodes, 'withdrawal settlement');
    for (final n in nodes) {
      final st = await n.reduced();
      checkEq(st.withdrawals['w-1']!.status, WithdrawalStatus.approved,
          '${n.label}: withdrawal approved by the other user');
    }

    // --- Scenario 7: emergency purchase over its fund ransacks the chest ----
    print('\n== 7. emergency over-fund ransack ==');
    // efHealth is funded 5000/mo by Alice-Fun; a July emergency of 8000 exceeds
    // the 5000 balance, drawing the 3000 excess from the war chest.
    await c.author([
      purchase(c, bob, 'p-emergency', const EmergencyCharge(efHealth), 8000,
          july(15),
          note: 'vet bill'),
    ]);
    await convergeAll(nodes);
    await assertConverged(nodes, 'ransack');
    for (final n in nodes) {
      final st = await n.reduced();
      checkEq(st.ransacks.length, 1, '${n.label}: exactly one ransack');
      final r = st.ransacks.single;
      checkEq(r.fundId, efHealth, '${n.label}: ransack names the fund');
      checkEq(r.excessCents, 3000, '${n.label}: ransack excess = 3000');
    }

    // --- Scenario 8: receipt attached on one, opens + lands on the others ---
    print('\n== 8. receipt propagation + library placement ==');
    final jpeg = _fakeJpeg();
    final sha = sha256.convert(jpeg).toString();
    await a.blobs.save(jpeg);
    await a.author([
      purchase(a, alice, 'p-receipt', const SliceCharge(sGroceries), 4250,
          july(4),
          merchant: 'Safeway', taxDeductible: true),
      ReceiptAttached(
        eventId: uuidv7(),
        deviceId: a.deviceId,
        userId: alice,
        occurredAt: july(4),
        createdAt: july(4),
        purchaseId: 'p-receipt',
        sha256: sha,
        mimeType: 'image/jpeg',
        sizeBytes: jpeg.length,
      ),
    ]);
    await convergeAll(nodes);
    await assertConverged(nodes, 'receipt attach');
    for (final n in [b, c]) {
      check(await n.blobs.exists(sha),
          '${n.label}: receipt blob synced and opens');
      final bytes = await n.blobs.read(sha);
      check(sha256.convert(bytes).toString() == sha,
          '${n.label}: receipt bytes intact after sync');
    }
    // Project the library on the phone and confirm the deterministic path.
    final libRoot = '${c.dir.path}/library';
    final written = await projectReceiptLibrary(libRoot, await c.reduced(), c.blobs);
    const wantPath = '2026/Groceries/2026-07-04_Safeway_42.50.jpg';
    check(written.contains(wantPath),
        'receipt library places it at $wantPath (got $written)');
    check(File('$libRoot/$wantPath').existsSync(),
        'library file exists on disk');

    // --- Scenario 9: kill one hub, converge through the other ---------------
    print('\n== 9. kill a hub, keep converging ==');
    await b.httpServer!.close(force: true); // hub-B dies
    b.httpServer = null;
    await a.author([
      purchase(a, alice, 'p-after-kill', const SliceCharge(sAliceFun), 1500,
          july(20), merchant: 'PostOutage'),
    ]);
    // A can no longer reach hub-B (its only paired hub); its sync surfaces the
    // failure but does not throw. Convergence proceeds through hub-A: the phone
    // pushes to hub-A and desktop-B pulls from hub-A.
    final aResult = await a.client.syncOnce();
    check(aResult.hubs.any((h) => !h.ok),
        'desktop-A surfaces the dead hub without throwing');
    // Phone still reaches hub-A; pull A's new event and it reaches B via hub-A.
    for (var i = 0; i < 4; i++) {
      await c.client.syncOnce();
      await b.client.syncOnce();
    }
    await assertConverged(nodes, 'convergence through the surviving hub');
    for (final n in nodes) {
      final st = await n.reduced();
      check(st.purchases.containsKey('p-after-kill'),
          '${n.label}: post-outage event converged via hub-A');
    }

    // --- Scenario 10: export-with-receipts into a fresh instance ------------
    print('\n== 10. export into a fresh instance ==');
    final fresh = Node('fresh-D', await _sub(root, 'D'), alice);
    final zip = await exportEventsZip(await a.db.eventsDao.allEvents(), a.blobs);
    final imported = readEventsZip(zip);
    await fresh.author(imported.events);
    await saveImportedBlobs(imported, fresh.blobs);
    final freshSnap = await fresh.snapshot();
    final aSnap = await a.snapshot();
    check(freshSnap == aSnap,
        'fresh instance reproduces identical HouseholdState from export');
    check(await fresh.blobs.exists(sha),
        'fresh instance holds the exported receipt blob');

    // --- Scenario 11: tax package from the fresh instance matches -----------
    print('\n== 11. tax package parity ==');
    final aPkg = buildTaxPackage(await a.reduced(), year: 2026, userNames: userNames);
    final freshPkg =
        buildTaxPackage(await fresh.reduced(), year: 2026, userNames: userNames);
    check(aPkg.csv == freshPkg.csv, 'tax summary.csv matches the original');
    check(aPkg.csv.contains('Safeway') && aPkg.csv.contains('42.50'),
        'tax summary lists the deductible Safeway receipt');
    check(_receiptsEqual(aPkg.receipts, freshPkg.receipts),
        'tax package receipt file list matches the original');
    await fresh.close();

    // --- Scenario 12: defensive import handling -----------------------------
    print('\n== 12. corrupt import + tampered blob rejected ==');
    var corruptRejected = false;
    try {
      importEventsJsonl('{"not":"an event"}\n@@@garbage@@@');
    } on ImportException {
      corruptRejected = true;
    }
    check(corruptRejected, 'corrupt .dbevents import raises ImportException');

    var tamperRejected = false;
    final tampered = _tamperOneBlob(zip);
    try {
      readEventsZip(tampered);
    } on BlobIntegrityException {
      tamperRejected = true;
    }
    check(tamperRejected, 'tampered blob raises BlobIntegrityException');
  } finally {
    for (final n in nodes) {
      await n.close();
    }
    await root.delete(recursive: true);
  }

  print('\n${_failures == 0 ? "ALL E2E SCENARIOS PASSED" : "$_failures E2E ASSERTION(S) FAILED"}');
  exit(_failures == 0 ? 0 : 1);
}

// ---- convergence helpers ----------------------------------------------------

/// Runs sync rounds across all nodes until snapshots agree and no events move,
/// modelling gossip converging over the multi-hub mesh in a bounded number of
/// cycles.
Future<void> convergeAll(List<Node> nodes) async {
  for (var round = 0; round < 10; round++) {
    var moved = 0;
    for (final n in nodes) {
      if (n.httpServer == null && n.hub != null) continue; // dead hub host
      final r = await n.client.syncOnce();
      moved += r.pulled;
    }
    final snaps = <String>{};
    for (final n in nodes) {
      snaps.add(await n.snapshot());
    }
    if (moved == 0 && snaps.length == 1) return;
  }
}

Future<void> assertConverged(List<Node> nodes, String label) async {
  final snaps = <String, String>{};
  for (final n in nodes) {
    snaps[n.label] = await n.snapshot();
  }
  final distinct = snaps.values.toSet();
  check(distinct.length == 1, '$label: all instances identical');
  if (distinct.length != 1) {
    snaps.forEach((k, v) => print('    $k => $v'));
  }
}

// ---- fixtures ---------------------------------------------------------------

Future<Directory> _sub(Directory root, String name) =>
    Directory('${root.path}/$name').create(recursive: true);

/// A minimal valid JPEG (SOI + APP0 JFIF + EOI). Enough to be a stable,
/// content-addressed blob; the harness never decodes it.
List<int> _fakeJpeg() => const [
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9,
    ];

/// Flips the last byte of the first `blobs/` entry to simulate a tampered zip.
List<int> _tamperOneBlob(List<int> zipBytes) {
  final imported = readEventsZip(zipBytes);
  final sha = imported.blobs.keys.first;
  final bytes = [...imported.blobs[sha]!];
  bytes[bytes.length - 1] ^= 0xFF;
  // Re-pack a zip that claims the original hash but carries mutated bytes.
  final events = imported.events;
  final jsonl = exportEventsJsonl(events);
  final archive = _rawZip({
    'events.jsonl': utf8.encode(jsonl),
    'blobs/$sha': bytes,
  });
  return archive;
}

List<int> _rawZip(Map<String, List<int>> entries) {
  final archive = Archive();
  entries.forEach((name, bytes) {
    archive.addFile(ArchiveFile.bytes(name, bytes));
  });
  return ZipEncoder().encodeBytes(archive);
}

bool _receiptsEqual(List<TaxReceiptFile> x, List<TaxReceiptFile> y) {
  if (x.length != y.length) return false;
  for (var i = 0; i < x.length; i++) {
    if (x[i] != y[i]) return false;
  }
  return true;
}
