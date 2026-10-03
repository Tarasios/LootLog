/// The on-device [GameEventStore]: the game event log in the app's drift
/// database, in its own `game_events` table beside (never inside) the ledger's
/// event log.
library;

import '../../data/db/database.dart';
import '../domain/game_event.dart';
import '../domain/game_event_store.dart';

class DriftGameEventStore implements GameEventStore {
  DriftGameEventStore(this._dao);

  final GameEventsDao _dao;

  @override
  Future<void> append(Iterable<GameEvent> events) =>
      _dao.appendGameEvents(events);

  @override
  Future<List<GameEvent>> all() => _dao.allGameEvents();

  @override
  Stream<List<GameEvent>> watchAll() => _dao.watchAllGameEvents();
}
