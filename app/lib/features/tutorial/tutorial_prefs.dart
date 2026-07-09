/// Device-local persistence for whether the first-use tour has been seen.
///
/// Like the presentation skin, this is a per-device preference (not household
/// data), so it lives in a tiny file in the app documents directory rather than
/// the event log. It defaults to "seen" so the tour never flashes before the
/// real value loads; a fresh install has no file, which reads as not-seen and
/// triggers the tour once.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _tutorialFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'tutorial_seen.txt'));
}

/// Loads whether the tour has been completed/skipped. A missing file (fresh
/// install) reads as not-seen.
Future<bool> loadTutorialSeen() async {
  final f = await _tutorialFile();
  if (!f.existsSync()) return false;
  return f.readAsStringSync().trim() == 'true';
}

/// Persists the seen flag.
Future<void> saveTutorialSeen(bool seen) async {
  final f = await _tutorialFile();
  f.writeAsStringSync(seen ? 'true' : 'false', flush: true);
}

/// Tracks whether the first-use tour has been seen on this device. Starts at
/// `true` (assume seen) and flips to `false` once the restore confirms a fresh
/// install, so the gate only ever triggers on a genuine first run.
class TutorialSeenNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_restore());
    return true;
  }

  Future<void> _restore() async {
    final seen = await loadTutorialSeen();
    if (seen != state) state = seen;
  }

  /// Records that the tour has been completed or skipped.
  Future<void> markSeen() async {
    state = true;
    await saveTutorialSeen(true);
  }

  /// Resets the flag (used only in tests / debug) so the tour shows again.
  Future<void> reset() async {
    state = false;
    await saveTutorialSeen(false);
  }
}

/// Whether this device has seen the first-use tour.
final tutorialSeenProvider =
    NotifierProvider<TutorialSeenNotifier, bool>(TutorialSeenNotifier.new);
