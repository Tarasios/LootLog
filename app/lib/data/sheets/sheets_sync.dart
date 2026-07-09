/// Optional Google Sheets sync — the ONLY feature in DuoBudget permitted to
/// contact an outside service, and the only one that ever sends data off the
/// local network.
///
/// Everything here is designed around three non-negotiables:
///
///  * **Off by default.** [SheetsSyncSettings] starts disabled; nothing is ever
///    sent until the user explicitly opts in, having seen [kSheetsPrivacyWarning].
///  * **Isolated behind an interface.** The rest of the app depends only on the
///    [SheetsClient] abstraction and the pure [SheetsSyncService] gate. No real
///    Google API client ships in the core app: the default binding is
///    [UnavailableSheetsClient], so the app builds and fully functions with the
///    integration absent. A concrete client can be dropped in behind the same
///    interface without any other feature learning about it.
///  * **User-supplied credentials.** The user brings their own OAuth client and
///    refresh token ([SheetsCredentials]); we store no shared secret and no
///    other feature may depend on this one.
///
/// This file is pure Dart with zero Flutter imports so the gating logic is
/// unit-testable; the platform-guarded provider lives in `sheets_provider.dart`.
library;

import '../export/xlsx.dart';

/// The warning shown, and acknowledged, before Google Sheets sync can be turned
/// on. Deliberately blunt: this is the one place data leaves the device.
const String kSheetsPrivacyWarning =
    'Turning on Google Sheets sync sends a copy of your budget workbook to '
    'Google Sheets. Your data leaves your local network and this device. This '
    'is the only DuoBudget feature that ever contacts an outside service; it '
    'stays off until you turn it on, you provide your own Google credentials, '
    'and you can turn it off at any time. Nothing else in the app depends on it.';

/// The user-supplied OAuth credentials for their own Google account. DuoBudget
/// ships no client secret of its own; the user creates an OAuth client in the
/// Google Cloud console and supplies a refresh token (see `docs/exports.md`).
class SheetsCredentials {
  const SheetsCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.refreshToken,
  });

  final String clientId;
  final String clientSecret;
  final String refreshToken;

  /// Whether all three fields are present. An incomplete credential can never
  /// be used to push.
  bool get isComplete =>
      clientId.isNotEmpty && clientSecret.isNotEmpty && refreshToken.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'refreshToken': refreshToken,
      };

  static SheetsCredentials fromJson(Map<String, dynamic> json) =>
      SheetsCredentials(
        clientId: json['clientId'] as String? ?? '',
        clientSecret: json['clientSecret'] as String? ?? '',
        refreshToken: json['refreshToken'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is SheetsCredentials &&
      other.clientId == clientId &&
      other.clientSecret == clientSecret &&
      other.refreshToken == refreshToken;

  @override
  int get hashCode => Object.hash(clientId, clientSecret, refreshToken);
}

/// The device-local configuration of Google Sheets sync. This is not a ledger
/// event — no external-service state ever enters the event log — it is plain
/// device settings persisted outside the reducer.
class SheetsSyncSettings {
  const SheetsSyncSettings({
    this.enabled = false,
    this.spreadsheetId,
    this.pushAfterSync = false,
  });

  /// Off by default. When false, no push ever happens.
  final bool enabled;

  /// The target spreadsheet the workbook is written to.
  final String? spreadsheetId;

  /// When true, a successful hub/merge sync also pushes the workbook. Purely an
  /// opt-in convenience on top of the on-demand "Push now" action.
  final bool pushAfterSync;

  /// Whether sync is turned on AND has a target spreadsheet to write to.
  bool get isConfigured =>
      enabled && spreadsheetId != null && spreadsheetId!.trim().isNotEmpty;

  SheetsSyncSettings copyWith({
    bool? enabled,
    String? spreadsheetId,
    bool? pushAfterSync,
  }) =>
      SheetsSyncSettings(
        enabled: enabled ?? this.enabled,
        spreadsheetId: spreadsheetId ?? this.spreadsheetId,
        pushAfterSync: pushAfterSync ?? this.pushAfterSync,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'spreadsheetId': spreadsheetId,
        'pushAfterSync': pushAfterSync,
      };

  static SheetsSyncSettings fromJson(Map<String, dynamic> json) =>
      SheetsSyncSettings(
        enabled: json['enabled'] as bool? ?? false,
        spreadsheetId: json['spreadsheetId'] as String?,
        pushAfterSync: json['pushAfterSync'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is SheetsSyncSettings &&
      other.enabled == enabled &&
      other.spreadsheetId == spreadsheetId &&
      other.pushAfterSync == pushAfterSync;

  @override
  int get hashCode => Object.hash(enabled, spreadsheetId, pushAfterSync);
}

/// The result of a successful push.
class SheetsPushResult {
  const SheetsPushResult({
    required this.updatedSheets,
    required this.spreadsheetUrl,
  });

  final int updatedSheets;
  final String spreadsheetUrl;
}

/// Why a push did or did not happen.
enum SheetsPushStatus {
  /// The workbook was pushed to the spreadsheet.
  pushed,

  /// Sync is turned off (the default) — nothing was sent.
  skippedDisabled,

  /// Sync is on but not fully configured (no spreadsheet or credentials).
  skippedNotConfigured,

  /// No Google Sheets client is available in this build.
  unsupported,

  /// The client attempted the push and it failed; see [SheetsPushOutcome.message].
  failed,
}

/// The outcome of asking the [SheetsSyncService] to push. Always non-throwing:
/// failures are reported as [SheetsPushStatus.failed] with a [message].
class SheetsPushOutcome {
  const SheetsPushOutcome(this.status, {this.result, this.message});

  final SheetsPushStatus status;
  final SheetsPushResult? result;
  final String? message;

  bool get didPush => status == SheetsPushStatus.pushed;
}

/// The isolation boundary: the only thing the app calls to actually talk to
/// Google. Implementations must be self-contained — the app depends on nothing
/// Google-specific beyond this interface.
abstract interface class SheetsClient {
  /// Whether a working Google Sheets client is available on this platform and
  /// in this build.
  bool get isSupported;

  /// Pushes [workbook] to the spreadsheet identified by [spreadsheetId] using
  /// the caller's [credentials]. Throws on failure; the [SheetsSyncService]
  /// wraps the call so callers never see the exception.
  Future<SheetsPushResult> push(
    XlsxWorkbook workbook, {
    required SheetsCredentials credentials,
    required String spreadsheetId,
  });
}

/// The default binding shipped in the core app: no Google integration present.
/// Reports [isSupported] false and refuses to push, so every screen and flow
/// works with the feature entirely absent.
class UnavailableSheetsClient implements SheetsClient {
  const UnavailableSheetsClient();

  @override
  bool get isSupported => false;

  @override
  Future<SheetsPushResult> push(
    XlsxWorkbook workbook, {
    required SheetsCredentials credentials,
    required String spreadsheetId,
  }) async =>
      throw UnsupportedError('Google Sheets sync is not available in this build');
}

/// The pure gate around a [SheetsClient]: it decides whether a push is allowed
/// (respecting the off-by-default flag, configuration, credential completeness,
/// and client availability) before ever handing bytes to the client.
class SheetsSyncService {
  const SheetsSyncService(this.client);

  final SheetsClient client;

  /// An on-demand push (the "Push now" button). Returns a [SheetsPushOutcome]
  /// describing what happened; never throws.
  Future<SheetsPushOutcome> pushNow(
    XlsxWorkbook workbook, {
    required SheetsSyncSettings settings,
    required SheetsCredentials? credentials,
  }) =>
      _push(workbook, settings: settings, credentials: credentials);

  /// A push triggered after a hub/merge sync. In addition to the normal gates,
  /// it only runs when [SheetsSyncSettings.pushAfterSync] is on; otherwise it
  /// reports [SheetsPushStatus.skippedDisabled] and sends nothing.
  Future<SheetsPushOutcome> maybePushAfterSync(
    XlsxWorkbook workbook, {
    required SheetsSyncSettings settings,
    required SheetsCredentials? credentials,
  }) {
    if (!settings.pushAfterSync) {
      return Future.value(
        const SheetsPushOutcome(SheetsPushStatus.skippedDisabled),
      );
    }
    return _push(workbook, settings: settings, credentials: credentials);
  }

  Future<SheetsPushOutcome> _push(
    XlsxWorkbook workbook, {
    required SheetsSyncSettings settings,
    required SheetsCredentials? credentials,
  }) async {
    if (!settings.enabled) {
      return const SheetsPushOutcome(SheetsPushStatus.skippedDisabled);
    }
    if (!client.isSupported) {
      return const SheetsPushOutcome(SheetsPushStatus.unsupported);
    }
    if (!settings.isConfigured ||
        credentials == null ||
        !credentials.isComplete) {
      return const SheetsPushOutcome(SheetsPushStatus.skippedNotConfigured);
    }
    try {
      final result = await client.push(
        workbook,
        credentials: credentials,
        spreadsheetId: settings.spreadsheetId!,
      );
      return SheetsPushOutcome(SheetsPushStatus.pushed, result: result);
    } on Object catch (e) {
      return SheetsPushOutcome(SheetsPushStatus.failed, message: '$e');
    }
  }
}
