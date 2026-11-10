/// Whether the town's docked quest board is folded away on this device: a
/// per-device layout preference kept in a tiny file in the app documents
/// directory, like the Adventure render tier (`skin_prefs.dart`). It never
/// syncs. Defaults to open, so goals stay front and centre.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<File> _collapsedFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File(p.join(directory.path, 'quest_board_collapsed.txt'));
}

/// Loads the stored choice; open unless this device folded the board away.
Future<bool> loadQuestBoardCollapsed() async {
  final file = await _collapsedFile();
  if (!file.existsSync()) return false;
  return file.readAsStringSync().trim() == 'collapsed';
}

Future<void> saveQuestBoardCollapsed(bool collapsed) async {
  final file = await _collapsedFile();
  file.writeAsStringSync(collapsed ? 'collapsed' : 'open', flush: true);
}

/// The board's folded state: open until the stored choice loads, then
/// written through on [select]. A device with no documents directory (or a
/// test) keeps it in memory only.
class QuestBoardCollapsedNotifier extends Notifier<bool> {
  @override
  bool build() {
    unawaited(_restore());
    return false;
  }

  Future<void> _restore() async {
    try {
      final loaded = await loadQuestBoardCollapsed();
      if (loaded != state) state = loaded;
    } on Object {
      // No stored choice to read: stay open.
    }
  }

  Future<void> select(bool collapsed) async {
    state = collapsed;
    try {
      await saveQuestBoardCollapsed(collapsed);
    } on Object {
      // Not persisted this time; the board still folds for this visit.
    }
  }
}

final questBoardCollapsedProvider =
    NotifierProvider<QuestBoardCollapsedNotifier, bool>(
      QuestBoardCollapsedNotifier.new,
    );
