/// Tests the optional Google Sheets sync gate: off by default, isolated behind
/// an interface, and never pushing unless explicitly enabled, configured, and
/// backed by a supported client with complete credentials.
library;

import 'package:lootlog/data/export/xlsx.dart';
import 'package:lootlog/data/sheets/sheets_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// A recording fake standing in for a real Google client.
class FakeSheetsClient implements SheetsClient {
  FakeSheetsClient({this.supported = true, this.throwOnPush = false});

  final bool supported;
  final bool throwOnPush;
  int pushes = 0;
  XlsxWorkbook? lastWorkbook;

  @override
  bool get isSupported => supported;

  @override
  Future<SheetsPushResult> push(
    XlsxWorkbook workbook, {
    required SheetsCredentials credentials,
    required String spreadsheetId,
  }) async {
    pushes++;
    lastWorkbook = workbook;
    if (throwOnPush) throw StateError('network down');
    return SheetsPushResult(
      updatedSheets: workbook.sheets.length,
      spreadsheetUrl: 'https://sheets.example/$spreadsheetId',
    );
  }
}

final _workbook = XlsxWorkbook([
  const XlsxSheet(name: 'Transactions', header: ['A'], rows: []),
]);

const _creds = SheetsCredentials(
  clientId: 'cid',
  clientSecret: 'secret',
  refreshToken: 'refresh',
);

const _onSettings = SheetsSyncSettings(enabled: true, spreadsheetId: 'sheet123');

void main() {
  test('sync is off by default and not configured', () {
    const s = SheetsSyncSettings();
    expect(s.enabled, isFalse);
    expect(s.isConfigured, isFalse);
    expect(s.pushAfterSync, isFalse);
  });

  test('the privacy warning names the network boundary', () {
    expect(kSheetsPrivacyWarning, contains('leaves your local network'));
  });

  test('the shipped default client is unavailable and refuses to push', () async {
    const client = UnavailableSheetsClient();
    expect(client.isSupported, isFalse);
    expect(
      () => client.push(_workbook, credentials: _creds, spreadsheetId: 's'),
      throwsUnsupportedError,
    );
  });

  test('disabled sync never touches the client', () async {
    final client = FakeSheetsClient();
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: const SheetsSyncSettings(),
      credentials: _creds,
    );
    expect(outcome.status, SheetsPushStatus.skippedDisabled);
    expect(client.pushes, 0);
  });

  test('enabled but unconfigured (no spreadsheet) does not push', () async {
    final client = FakeSheetsClient();
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: const SheetsSyncSettings(enabled: true),
      credentials: _creds,
    );
    expect(outcome.status, SheetsPushStatus.skippedNotConfigured);
    expect(client.pushes, 0);
  });

  test('enabled and configured but no credentials does not push', () async {
    final client = FakeSheetsClient();
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: _onSettings,
      credentials: null,
    );
    expect(outcome.status, SheetsPushStatus.skippedNotConfigured);
    expect(client.pushes, 0);
  });

  test('an unsupported client reports unsupported, never pushes', () async {
    final client = FakeSheetsClient(supported: false);
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: _onSettings,
      credentials: _creds,
    );
    expect(outcome.status, SheetsPushStatus.unsupported);
    expect(client.pushes, 0);
  });

  test('fully enabled push sends the same workbook to the client', () async {
    final client = FakeSheetsClient();
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: _onSettings,
      credentials: _creds,
    );
    expect(outcome.status, SheetsPushStatus.pushed);
    expect(outcome.result!.spreadsheetUrl, contains('sheet123'));
    expect(client.pushes, 1);
    expect(identical(client.lastWorkbook, _workbook), isTrue);
  });

  test('client failures surface as a non-throwing failed outcome', () async {
    final client = FakeSheetsClient(throwOnPush: true);
    final service = SheetsSyncService(client);
    final outcome = await service.pushNow(
      _workbook,
      settings: _onSettings,
      credentials: _creds,
    );
    expect(outcome.status, SheetsPushStatus.failed);
    expect(outcome.message, contains('network down'));
  });

  test('after-sync push only runs when pushAfterSync is on', () async {
    final client = FakeSheetsClient();
    final service = SheetsSyncService(client);

    final skipped = await service.maybePushAfterSync(
      _workbook,
      settings: _onSettings, // pushAfterSync defaults to false
      credentials: _creds,
    );
    expect(skipped.status, SheetsPushStatus.skippedDisabled);
    expect(client.pushes, 0);

    final pushed = await service.maybePushAfterSync(
      _workbook,
      settings: _onSettings.copyWith(pushAfterSync: true),
      credentials: _creds,
    );
    expect(pushed.status, SheetsPushStatus.pushed);
    expect(client.pushes, 1);
  });

  test('settings and credentials round-trip through JSON', () {
    final settings = _onSettings.copyWith(pushAfterSync: true);
    expect(
      SheetsSyncSettings.fromJson(settings.toJson()),
      settings,
    );
    expect(SheetsCredentials.fromJson(_creds.toJson()), _creds);
    expect(_creds.isComplete, isTrue);
    expect(
      const SheetsCredentials(clientId: '', clientSecret: '', refreshToken: '')
          .isComplete,
      isFalse,
    );
  });
}
