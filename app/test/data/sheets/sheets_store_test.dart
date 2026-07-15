/// Update-safety: the Google Sheets settings/credentials in secure storage
/// (workstream G). The OS keeps `flutter_secure_storage` values across app
/// updates; what LootLog must guarantee is the contract on top of it — the
/// keys stay stable, values round-trip, and anything old or corrupted decodes
/// to the safe, off-by-default state instead of crashing or turning the only
/// external service ON by surprise.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/sheets/sheets_store.dart';
import 'package:lootlog/data/sheets/sheets_sync.dart';

/// A map-backed stand-in for the platform keystore.
class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this.values);
  final Map<String, String> values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  test('settings and credentials round-trip across a "restart"', () async {
    final keystore = <String, String>{};
    final store = SheetsSyncStore(_FakeSecureStorage(keystore));
    await store.saveSettings(const SheetsSyncSettings(
      enabled: true,
      spreadsheetId: 'sheet-1',
      pushAfterSync: true,
    ));
    await store.saveCredentials(const SheetsCredentials(
      clientId: 'id',
      clientSecret: 'secret',
      refreshToken: 'refresh',
    ));

    // A new store over the same keystore contents — the updated app reading
    // what the old app wrote.
    final reopened = SheetsSyncStore(_FakeSecureStorage(keystore));
    final settings = await reopened.loadSettings();
    expect(settings.enabled, isTrue);
    expect(settings.spreadsheetId, 'sheet-1');
    expect(settings.pushAfterSync, isTrue);
    final creds = await reopened.loadCredentials();
    expect(creds, isNotNull);
    expect(creds!.isComplete, isTrue);
    expect(creds.refreshToken, 'refresh');
  });

  test('missing or corrupted values decode to the safe defaults', () async {
    final store = SheetsSyncStore(_FakeSecureStorage({
      'sheets_sync_settings': '{not json',
      'sheets_sync_credentials': '[]',
    }));

    // Corrupted settings must never read as enabled (data leaves the local
    // network only by explicit opt-in).
    final settings = await store.loadSettings();
    expect(settings.enabled, isFalse);
    expect(await store.loadCredentials(), isNull);

    final empty = SheetsSyncStore(_FakeSecureStorage({}));
    expect((await empty.loadSettings()).enabled, isFalse);
    expect(await empty.loadCredentials(), isNull);
  });
}
