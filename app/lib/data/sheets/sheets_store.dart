/// Device-local persistence for the optional Google Sheets sync configuration.
///
/// Settings and the user's OAuth credentials live in `flutter_secure_storage`,
/// never in the event log — no external-service state ever reaches the reducer,
/// and the credentials never sync between devices. Absent any stored value the
/// store returns the off-by-default [SheetsSyncSettings], so a fresh device is
/// always in the safe, nothing-leaves state.
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sheets_sync.dart';

/// Reads and writes the Google Sheets sync settings and credentials.
class SheetsSyncStore {
  const SheetsSyncStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _settingsKey = 'sheets_sync_settings';
  static const _credentialsKey = 'sheets_sync_credentials';

  /// The stored settings, or the off-by-default settings when none are saved.
  Future<SheetsSyncSettings> loadSettings() async {
    final raw = await _storage.read(key: _settingsKey);
    if (raw == null || raw.isEmpty) return const SheetsSyncSettings();
    try {
      return SheetsSyncSettings.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return const SheetsSyncSettings();
    }
  }

  Future<void> saveSettings(SheetsSyncSettings settings) =>
      _storage.write(key: _settingsKey, value: jsonEncode(settings.toJson()));

  /// The stored credentials, or null when the user has supplied none.
  Future<SheetsCredentials?> loadCredentials() async {
    final raw = await _storage.read(key: _credentialsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SheetsCredentials.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } on Object {
      return null;
    }
  }

  Future<void> saveCredentials(SheetsCredentials credentials) => _storage.write(
        key: _credentialsKey,
        value: jsonEncode(credentials.toJson()),
      );

  /// Forgets the credentials (e.g. when the user turns sync off for good).
  Future<void> clearCredentials() => _storage.delete(key: _credentialsKey);
}
