/// The neighbourly game events: a cheer one Adventure adult sends a
/// neighbouring town (`town/cheers.dart`). Part of `game_event.dart` so it
/// joins the sealed [GameEvent] hierarchy.
///
/// New to stage 2, so an older build decodes it as an [UnknownGameEvent]
/// and relays it verbatim. Purely cosmetic: it moves no gem or material.
part of 'game_event.dart';

/// The neighbourly event types this build understands (in [kGameEventTypes]).
const List<String> _kSocialEventTypes = ['CheerSent'];

/// Decodes a neighbourly event, or returns null for a type that is not one.
GameEvent? _decodeSocial(_Envelope envelope, String type, Map<String, dynamic> payload) {
  switch (type) {
    case 'CheerSent':
      return CheerSent(
        eventId: envelope.eventId,
        deviceId: envelope.deviceId,
        actorId: envelope.actorId,
        occurredAt: envelope.occurredAt,
        createdAt: envelope.createdAt,
        schemaVersion: envelope.schemaVersion,
        toPersonId: payload['toPersonId'] as String,
        day: GameDay.parse(payload['day'] as String),
      );
  }
  return null;
}

/// The actor cheered [toPersonId]'s town on household [day]. One per sender,
/// neighbour and day: the projection keeps the earliest copy (see
/// `cheerId`), so two devices cheering the same day show one cheer.
class CheerSent extends GameEvent {
  const CheerSent({
    required super.eventId,
    required super.deviceId,
    required super.actorId,
    required super.occurredAt,
    required super.createdAt,
    super.schemaVersion,
    required this.toPersonId,
    required this.day,
  });

  final String toPersonId;
  final GameDay day;

  @override
  String get type => 'CheerSent';

  @override
  Map<String, dynamic> payload() => {'toPersonId': toPersonId, 'day': day.toKey()};
}
