/// Riverpod wiring for the optional Google Sheets sync, kept apart from the pure
/// gating logic so `sheets_sync.dart` stays Flutter-free and unit-testable.
///
/// The client binding is platform-guarded exactly like on-device OCR: the core
/// app ships only [UnavailableSheetsClient], so the feature is absent by default
/// and everything else works without it. A concrete client can be substituted
/// by overriding [sheetsClientProvider] — no other provider changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sheets_store.dart';
import 'sheets_sync.dart';

/// The Google Sheets client for this build. No real client is bundled in the
/// core app, so — exactly like the platform-guarded OCR plugin — this is the
/// unavailable stub on every platform. A concrete, platform-specific binding
/// can be substituted by overriding this provider, with no change to callers.
final sheetsClientProvider = Provider<SheetsClient>(
  (ref) => const UnavailableSheetsClient(),
);

/// The pure gate around whichever [SheetsClient] is bound.
final sheetsSyncServiceProvider = Provider<SheetsSyncService>(
  (ref) => SheetsSyncService(ref.watch(sheetsClientProvider)),
);

/// Device-local store for the sync settings and user credentials.
final sheetsSyncStoreProvider = Provider<SheetsSyncStore>(
  (ref) => const SheetsSyncStore(FlutterSecureStorage()),
);
