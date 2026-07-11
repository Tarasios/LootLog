/// Device-local persistence for first-use tour progress.
///
/// Like the presentation skin, this is a per-device preference (not household
/// data), so it lives in a tiny file in the app documents directory rather
/// than the event log. The file keeps its legacy name and 'true' payload so
/// devices upgrading from the boolean era read as completed.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _tutorialFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File(p.join(dir.path, 'tutorial_seen.txt'));
}

/// How far this device has gotten through the tour.
@immutable
class TutorialProgress {
  const TutorialProgress({required this.completed, required this.stepIndex});

  /// Finished or explicitly skipped — the gate never auto-shows again.
  final bool completed;

  /// The step to resume at when not [completed].
  final int stepIndex;

  static const done = TutorialProgress(completed: true, stepIndex: 0);
  static const fresh = TutorialProgress(completed: false, stepIndex: 0);

  /// Decodes a stored value. 'true' (also the legacy boolean file) means
  /// completed; 'step:N' resumes at N; anything else reads as fresh.
  static TutorialProgress decode(String raw) {
    final v = raw.trim();
    if (v == 'true') return done;
    if (v.startsWith('step:')) {
      final n = int.tryParse(v.substring('step:'.length)) ?? 0;
      return TutorialProgress(completed: false, stepIndex: n < 0 ? 0 : n);
    }
    return fresh;
  }

  String encode() => completed ? 'true' : 'step:$stepIndex';

  @override
  bool operator ==(Object other) =>
      other is TutorialProgress &&
      other.completed == completed &&
      other.stepIndex == stepIndex;

  @override
  int get hashCode => Object.hash(completed, stepIndex);
}

/// Decides what to persist after the tour dialog closes.
///
/// `dialogOutcome == true` means Done/Skip was pressed — always completed.
/// Otherwise the dialog was dismissed some other way (barrier tap, navigator
/// swap): if the tour was already completed on entry, that stays untouched
/// (a replay dismissal must never un-complete a finished tour); otherwise the
/// resume step is saved so the next launch picks up where it left off.
TutorialProgress nextProgressAfterDismissal({
  required TutorialProgress before,
  required bool? dialogOutcome,
  required int lastShownStep,
}) {
  if (dialogOutcome == true || before.completed) return TutorialProgress.done;
  return TutorialProgress(completed: false, stepIndex: lastShownStep);
}

/// Loads the stored progress. A missing file (fresh install) reads as fresh.
Future<TutorialProgress> loadTutorialProgress() async {
  final f = await _tutorialFile();
  if (!f.existsSync()) return TutorialProgress.fresh;
  return TutorialProgress.decode(f.readAsStringSync());
}

/// Persists [progress].
Future<void> saveTutorialProgress(TutorialProgress progress) async {
  final f = await _tutorialFile();
  f.writeAsStringSync(progress.encode(), flush: true);
}

/// Tracks tour progress. Starts as completed (assume seen) and flips once the
/// async restore confirms otherwise, so the gate only triggers on a genuine
/// first run — never a flash while loading.
class TutorialProgressNotifier extends Notifier<TutorialProgress> {
  @override
  TutorialProgress build() {
    unawaited(_restore());
    return TutorialProgress.done;
  }

  Future<void> _restore() async {
    final loaded = await loadTutorialProgress();
    if (loaded != state) state = loaded;
  }

  /// Records that the tour was finished or explicitly skipped.
  Future<void> markCompleted() async {
    state = TutorialProgress.done;
    await saveTutorialProgress(state);
  }

  /// Records the step to resume at after a mid-tour dismissal.
  Future<void> saveStep(int stepIndex) async {
    state = TutorialProgress(completed: false, stepIndex: stepIndex);
    await saveTutorialProgress(state);
  }

  /// Resets progress so the tour shows again (Settings replay / tests).
  Future<void> reset() async {
    state = TutorialProgress.fresh;
    await saveTutorialProgress(state);
  }
}

/// This device's first-use tour progress.
final tutorialProgressProvider =
    NotifierProvider<TutorialProgressNotifier, TutorialProgress>(
        TutorialProgressNotifier.new);
