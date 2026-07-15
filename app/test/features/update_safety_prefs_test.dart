/// Update-safety: legacy pref-file compatibility (workstream G).
///
/// Every per-device preference lives in a tiny file in the app documents
/// directory. An app update must (a) read every value an older version could
/// have written — including the tutorial file's legacy boolean payload and
/// the receipt-mode file's legacy 'on'/'off' values — and (b) fall back to a
/// safe default on a missing or corrupted file, never crash. These tests run
/// the REAL loaders against a fake documents directory.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/blobs/receipt_offload.dart';
import 'package:lootlog/features/settings/visibility_prefs.dart';
import 'package:lootlog/features/tutorial/tutorial_prefs.dart';
import 'package:lootlog/game/skin_prefs.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Routes the documents directory to a per-test temp folder so the real
/// file-backed loaders run against controlled contents.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);
  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('lootlog-prefs');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  void write(String name, String content) =>
      File('${tmp.path}/$name').writeAsStringSync(content, flush: true);

  group('tutorial file (tutorial_seen.txt)', () {
    test('missing file reads as fresh', () async {
      expect(await loadTutorialProgress(), TutorialProgress.fresh);
    });

    test("the legacy boolean era's 'true' reads as completed", () async {
      write('tutorial_seen.txt', 'true');
      expect(await loadTutorialProgress(), TutorialProgress.done);
    });

    test('a resumable step survives and garbage falls back to fresh',
        () async {
      write('tutorial_seen.txt', 'step:3');
      expect((await loadTutorialProgress()).stepIndex, 3);

      write('tutorial_seen.txt', '???not-a-value???');
      expect(await loadTutorialProgress(), TutorialProgress.fresh);
    });
  });

  group('skin pref (app_skin.txt)', () {
    test('missing file defaults to Adventure (game first)', () async {
      expect(await loadAppSkin(), AppSkin.adventure);
    });

    test('a persisted Classic choice survives; garbage defaults to Adventure',
        () async {
      write('app_skin.txt', 'classic');
      expect(await loadAppSkin(), AppSkin.classic);

      write('app_skin.txt', 'retro-3d');
      expect(await loadAppSkin(), AppSkin.adventure);
    });
  });

  group('adventure tier pref (adventure_tier.txt)', () {
    test('missing file defaults to the shipping default tier', () async {
      expect(await loadAdventureTier(), defaultAdventureTier);
    });

    test('an explicit choice survives; garbage falls back to the default',
        () async {
      write('adventure_tier.txt', 'pixel');
      expect(await loadAdventureTier(), AdventureTier.pixel);

      write('adventure_tier.txt', 'text');
      expect(await loadAdventureTier(), AdventureTier.text);

      write('adventure_tier.txt', 'voxel');
      expect(await loadAdventureTier(), defaultAdventureTier);
    });
  });

  group('visibility pref (show_household_budgets.txt)', () {
    test('missing file defaults to full mutual visibility', () async {
      expect(await loadShowHouseholdBudgets(), isTrue);
    });

    test("'off' survives; anything unrecognised reads as on", () async {
      write('show_household_budgets.txt', 'off');
      expect(await loadShowHouseholdBudgets(), isFalse);

      write('show_household_budgets.txt', 'banana');
      expect(await loadShowHouseholdBudgets(), isTrue);
    });
  });

  group('receipt-mode pref (receipt_offload.txt)', () {
    ReceiptOffloadStore store() => ReceiptOffloadStore(dir: () async => tmp);

    test('missing file defaults to keep (every image stays)', () async {
      expect(await store().mode(), ReceiptStorageMode.keep);
    });

    test("the legacy two-state switch's 'on'/'off' still parse", () async {
      write('receipt_offload.txt', 'on');
      expect(await store().mode(), ReceiptStorageMode.offload);

      write('receipt_offload.txt', 'off');
      expect(await store().mode(), ReceiptStorageMode.keep);
    });

    test('current values survive and garbage falls back to keep', () async {
      write('receipt_offload.txt', 'offload');
      expect(await store().mode(), ReceiptStorageMode.offload);

      write('receipt_offload.txt', 'none');
      expect(await store().mode(), ReceiptStorageMode.none);

      write('receipt_offload.txt', 'shred-everything');
      expect(await store().mode(), ReceiptStorageMode.keep);
    });

    test('the offloaded-hash memory survives a restart', () async {
      final sha = 'd' * 64;
      await store().addAll([sha]);
      // A fresh store instance (the "updated app") still knows the hash, so
      // pulls keep skipping deliberately offloaded receipts.
      expect(await store().shas(), contains(sha));
    });
  });
}
