/// The sealed Event hierarchy. Every state change in LootLog is an immutable
/// event appended to the local log; derived state comes only from the reducer.
///
/// Every event shares a common envelope: `eventId` (UUIDv7), `deviceId`,
/// `userId`, `occurredAt` (user-editable; keys the month), `createdAt`, `type`
/// and a type-specific `payload`. Pure Dart, zero Flutter imports.
///
/// This file holds the envelope ([Event]) and [UnknownEvent]; the event types
/// are grouped by area in `event/` parts (purchases, budget, household, month
/// close, quests, war chest, savings, net worth, vacations, cosmetic and habit
/// markers), and `event/decoding.dart` maps each wire `type` back to its class.
library;

import 'time.dart';
import 'value_types.dart';

part 'event/budget_events.dart';
part 'event/cosmetic_and_habit_events.dart';
part 'event/decoding.dart';
part 'event/household_events.dart';
part 'event/month_close_events.dart';
part 'event/net_worth_events.dart';
part 'event/purchase_events.dart';
part 'event/quest_events.dart';
part 'event/savings_events.dart';
part 'event/vacation_events.dart';
part 'event/war_chest_events.dart';

/// Base class for every domain event.
sealed class Event {
  const Event({
    required this.eventId,
    required this.deviceId,
    required this.userId,
    required this.occurredAt,
    required this.createdAt,
  });

  /// UUIDv7 identity. Idempotency and total ordering both key off this.
  final String eventId;
  final String deviceId;

  /// The user who authored the event.
  final String userId;

  /// When the event is considered to have happened. User-editable; this is what
  /// keys the calendar month, not [createdAt].
  final DateTime occurredAt;

  /// When the event was actually recorded.
  final DateTime createdAt;

  /// The discriminator string used in JSON.
  String get type;

  /// The type-specific payload (without the envelope).
  Map<String, dynamic> payload();

  /// The household-timezone month this event is keyed to.
  Month get occurredMonth => Month.fromInstant(occurredAt);

  Map<String, dynamic> toJson() => {
    'eventId': eventId,
    'deviceId': deviceId,
    'userId': userId,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'type': type,
    'payload': payload(),
  };

  /// Reconstructs an event from its JSON envelope.
  static Event fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final eventId = json['eventId'] as String;
    final deviceId = json['deviceId'] as String;
    final userId = json['userId'] as String;
    final occurredAt = DateTime.parse(json['occurredAt'] as String).toUtc();
    final createdAt = DateTime.parse(json['createdAt'] as String).toUtc();
    final payload = (json['payload'] as Map).cast<String, dynamic>();

    return _decodeEvent(
      type,
      eventId,
      deviceId,
      userId,
      occurredAt,
      createdAt,
      payload,
    );
  }
}


/// An event of a type this version does not recognise (written by a newer
/// release). Preserved verbatim, stored, synced and exported like any other
/// event, and ignored by the reducer.
class UnknownEvent extends Event {
  const UnknownEvent({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.rawType,
    required this.rawPayload,
  });

  final String rawType;
  final Map<String, dynamic> rawPayload;

  @override
  String get type => rawType;

  @override
  Map<String, dynamic> payload() => rawPayload;
}
