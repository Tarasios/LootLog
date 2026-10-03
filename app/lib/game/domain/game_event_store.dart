/// Persistence boundary for the game event log, kept separate from the ledger's
/// event log. Like the ledger, the log is append-only and idempotent on
/// `eventId`: re-appending (a re-sync, an import, a replay) is a silent no-op.
///
/// Pure Dart, zero Flutter imports.
library;

import 'dart:async';

import 'game_event.dart';
import 'game_projection.dart';

/// An append-only, idempotent store of [GameEvent]s.
abstract interface class GameEventStore {
  /// Appends [events]; events whose id is already stored are ignored.
  Future<void> append(Iterable<GameEvent> events);

  /// The whole log in canonical `(occurredAt, eventId)` order.
  Future<List<GameEvent>> all();

  /// The whole log in canonical order, now and after every change.
  Stream<List<GameEvent>> watchAll();
}

/// An in-memory [GameEventStore] for tests and previews. Events are kept as
/// their JSON so reads hand back fresh decodes, exactly like a database.
class InMemoryGameEventStore implements GameEventStore {
  final Map<String, Map<String, dynamic>> _byId = {};
  final StreamController<void> _changes = StreamController.broadcast();

  @override
  Future<void> append(Iterable<GameEvent> events) async {
    var changed = false;
    for (final e in events) {
      if (!_byId.containsKey(e.eventId)) {
        _byId[e.eventId] = e.toJson();
        changed = true;
      }
    }
    if (changed) _changes.add(null);
  }

  @override
  Future<List<GameEvent>> all() async =>
      [for (final j in _byId.values) GameEvent.fromJson(j)]
        ..sort(compareGameEvents);

  @override
  Stream<List<GameEvent>> watchAll() {
    // Subscribe to changes before the first read, so an append racing the
    // listener is never missed.
    StreamSubscription<void>? changes;
    late final StreamController<List<GameEvent>> out;
    Future<void> emit() async {
      final events = await all();
      if (!out.isClosed) out.add(events);
    }

    out = StreamController(
      onListen: () {
        changes = _changes.stream.listen((_) => emit());
        emit();
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
  }

  Future<void> dispose() => _changes.close();
}
