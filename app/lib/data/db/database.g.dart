// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
mixin _$EventsDaoMixin on DatabaseAccessor<AppDatabase> {
  $EventsTable get events => attachedDatabase.events;
  EventsDaoManager get managers => EventsDaoManager(this);
}

class EventsDaoManager {
  final _$EventsDaoMixin _db;
  EventsDaoManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
}

mixin _$SyncDaoMixin on DatabaseAccessor<AppDatabase> {
  $EventsTable get events => attachedDatabase.events;
  $HubCursorsTable get hubCursors => attachedDatabase.hubCursors;
  $HubPushLogTable get hubPushLog => attachedDatabase.hubPushLog;
  SyncDaoManager get managers => SyncDaoManager(this);
}

class SyncDaoManager {
  final _$SyncDaoMixin _db;
  SyncDaoManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db.attachedDatabase, _db.events);
  $$HubCursorsTableTableManager get hubCursors =>
      $$HubCursorsTableTableManager(_db.attachedDatabase, _db.hubCursors);
  $$HubPushLogTableTableManager get hubPushLog =>
      $$HubPushLogTableTableManager(_db.attachedDatabase, _db.hubPushLog);
}

mixin _$LocalSetupDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalSetupRowsTable get localSetupRows => attachedDatabase.localSetupRows;
  LocalSetupDaoManager get managers => LocalSetupDaoManager(this);
}

class LocalSetupDaoManager {
  final _$LocalSetupDaoMixin _db;
  LocalSetupDaoManager(this._db);
  $$LocalSetupRowsTableTableManager get localSetupRows =>
      $$LocalSetupRowsTableTableManager(
        _db.attachedDatabase,
        _db.localSetupRows,
      );
}

class $EventsTable extends Events with TableInfo<$EventsTable, EventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    eventId,
    deviceId,
    userId,
    type,
    occurredAt,
    createdAt,
    payload,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  EventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventRow(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $EventsTable createAlias(String alias) {
    return $EventsTable(attachedDatabase, alias);
  }
}

class EventRow extends DataClass implements Insertable<EventRow> {
  final String eventId;
  final String deviceId;
  final String userId;
  final String type;

  /// User-editable instant that keys the calendar month.
  final DateTime occurredAt;

  /// When the event was actually recorded on some device.
  final DateTime createdAt;

  /// The type-specific payload as a JSON object string.
  final String payload;
  const EventRow({
    required this.eventId,
    required this.deviceId,
    required this.userId,
    required this.type,
    required this.occurredAt,
    required this.createdAt,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['device_id'] = Variable<String>(deviceId);
    map['user_id'] = Variable<String>(userId);
    map['type'] = Variable<String>(type);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  EventsCompanion toCompanion(bool nullToAbsent) {
    return EventsCompanion(
      eventId: Value(eventId),
      deviceId: Value(deviceId),
      userId: Value(userId),
      type: Value(type),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      payload: Value(payload),
    );
  }

  factory EventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventRow(
      eventId: serializer.fromJson<String>(json['eventId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      userId: serializer.fromJson<String>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'eventId': serializer.toJson<String>(eventId),
      'deviceId': serializer.toJson<String>(deviceId),
      'userId': serializer.toJson<String>(userId),
      'type': serializer.toJson<String>(type),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'payload': serializer.toJson<String>(payload),
    };
  }

  EventRow copyWith({
    String? eventId,
    String? deviceId,
    String? userId,
    String? type,
    DateTime? occurredAt,
    DateTime? createdAt,
    String? payload,
  }) => EventRow(
    eventId: eventId ?? this.eventId,
    deviceId: deviceId ?? this.deviceId,
    userId: userId ?? this.userId,
    type: type ?? this.type,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    payload: payload ?? this.payload,
  );
  EventRow copyWithCompanion(EventsCompanion data) {
    return EventRow(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventRow(')
          ..write('eventId: $eventId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    eventId,
    deviceId,
    userId,
    type,
    occurredAt,
    createdAt,
    payload,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventRow &&
          other.eventId == this.eventId &&
          other.deviceId == this.deviceId &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt &&
          other.payload == this.payload);
}

class EventsCompanion extends UpdateCompanion<EventRow> {
  final Value<String> eventId;
  final Value<String> deviceId;
  final Value<String> userId;
  final Value<String> type;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<String> payload;
  final Value<int> rowid;
  const EventsCompanion({
    this.eventId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.payload = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsCompanion.insert({
    required String eventId,
    required String deviceId,
    required String userId,
    required String type,
    required DateTime occurredAt,
    required DateTime createdAt,
    required String payload,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       deviceId = Value(deviceId),
       userId = Value(userId),
       type = Value(type),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       payload = Value(payload);
  static Insertable<EventRow> custom({
    Expression<String>? eventId,
    Expression<String>? deviceId,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<String>? payload,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (deviceId != null) 'device_id': deviceId,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (payload != null) 'payload': payload,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsCompanion copyWith({
    Value<String>? eventId,
    Value<String>? deviceId,
    Value<String>? userId,
    Value<String>? type,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<String>? payload,
    Value<int>? rowid,
  }) {
    return EventsCompanion(
      eventId: eventId ?? this.eventId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsCompanion(')
          ..write('eventId: $eventId, ')
          ..write('deviceId: $deviceId, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('payload: $payload, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HubCursorsTable extends HubCursors
    with TableInfo<$HubCursorsTable, HubCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HubCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hubIdMeta = const VerificationMeta('hubId');
  @override
  late final GeneratedColumn<String> hubId = GeneratedColumn<String>(
    'hub_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastPulledSeqMeta = const VerificationMeta(
    'lastPulledSeq',
  );
  @override
  late final GeneratedColumn<int> lastPulledSeq = GeneratedColumn<int>(
    'last_pulled_seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [hubId, lastPulledSeq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hub_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<HubCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hub_id')) {
      context.handle(
        _hubIdMeta,
        hubId.isAcceptableOrUnknown(data['hub_id']!, _hubIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hubIdMeta);
    }
    if (data.containsKey('last_pulled_seq')) {
      context.handle(
        _lastPulledSeqMeta,
        lastPulledSeq.isAcceptableOrUnknown(
          data['last_pulled_seq']!,
          _lastPulledSeqMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hubId};
  @override
  HubCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HubCursorRow(
      hubId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hub_id'],
      )!,
      lastPulledSeq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_seq'],
      )!,
    );
  }

  @override
  $HubCursorsTable createAlias(String alias) {
    return $HubCursorsTable(attachedDatabase, alias);
  }
}

class HubCursorRow extends DataClass implements Insertable<HubCursorRow> {
  final String hubId;

  /// The highest per-hub `hub_seq` this device has pulled from `hubId`.
  final int lastPulledSeq;
  const HubCursorRow({required this.hubId, required this.lastPulledSeq});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hub_id'] = Variable<String>(hubId);
    map['last_pulled_seq'] = Variable<int>(lastPulledSeq);
    return map;
  }

  HubCursorsCompanion toCompanion(bool nullToAbsent) {
    return HubCursorsCompanion(
      hubId: Value(hubId),
      lastPulledSeq: Value(lastPulledSeq),
    );
  }

  factory HubCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HubCursorRow(
      hubId: serializer.fromJson<String>(json['hubId']),
      lastPulledSeq: serializer.fromJson<int>(json['lastPulledSeq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hubId': serializer.toJson<String>(hubId),
      'lastPulledSeq': serializer.toJson<int>(lastPulledSeq),
    };
  }

  HubCursorRow copyWith({String? hubId, int? lastPulledSeq}) => HubCursorRow(
    hubId: hubId ?? this.hubId,
    lastPulledSeq: lastPulledSeq ?? this.lastPulledSeq,
  );
  HubCursorRow copyWithCompanion(HubCursorsCompanion data) {
    return HubCursorRow(
      hubId: data.hubId.present ? data.hubId.value : this.hubId,
      lastPulledSeq: data.lastPulledSeq.present
          ? data.lastPulledSeq.value
          : this.lastPulledSeq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HubCursorRow(')
          ..write('hubId: $hubId, ')
          ..write('lastPulledSeq: $lastPulledSeq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hubId, lastPulledSeq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HubCursorRow &&
          other.hubId == this.hubId &&
          other.lastPulledSeq == this.lastPulledSeq);
}

class HubCursorsCompanion extends UpdateCompanion<HubCursorRow> {
  final Value<String> hubId;
  final Value<int> lastPulledSeq;
  final Value<int> rowid;
  const HubCursorsCompanion({
    this.hubId = const Value.absent(),
    this.lastPulledSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HubCursorsCompanion.insert({
    required String hubId,
    this.lastPulledSeq = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : hubId = Value(hubId);
  static Insertable<HubCursorRow> custom({
    Expression<String>? hubId,
    Expression<int>? lastPulledSeq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hubId != null) 'hub_id': hubId,
      if (lastPulledSeq != null) 'last_pulled_seq': lastPulledSeq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HubCursorsCompanion copyWith({
    Value<String>? hubId,
    Value<int>? lastPulledSeq,
    Value<int>? rowid,
  }) {
    return HubCursorsCompanion(
      hubId: hubId ?? this.hubId,
      lastPulledSeq: lastPulledSeq ?? this.lastPulledSeq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hubId.present) {
      map['hub_id'] = Variable<String>(hubId.value);
    }
    if (lastPulledSeq.present) {
      map['last_pulled_seq'] = Variable<int>(lastPulledSeq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HubCursorsCompanion(')
          ..write('hubId: $hubId, ')
          ..write('lastPulledSeq: $lastPulledSeq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HubPushLogTable extends HubPushLog
    with TableInfo<$HubPushLogTable, HubPushRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HubPushLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _hubIdMeta = const VerificationMeta('hubId');
  @override
  late final GeneratedColumn<String> hubId = GeneratedColumn<String>(
    'hub_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [hubId, eventId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hub_push_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<HubPushRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('hub_id')) {
      context.handle(
        _hubIdMeta,
        hubId.isAcceptableOrUnknown(data['hub_id']!, _hubIdMeta),
      );
    } else if (isInserting) {
      context.missing(_hubIdMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {hubId, eventId};
  @override
  HubPushRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HubPushRow(
      hubId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hub_id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
    );
  }

  @override
  $HubPushLogTable createAlias(String alias) {
    return $HubPushLogTable(attachedDatabase, alias);
  }
}

class HubPushRow extends DataClass implements Insertable<HubPushRow> {
  final String hubId;
  final String eventId;
  const HubPushRow({required this.hubId, required this.eventId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['hub_id'] = Variable<String>(hubId);
    map['event_id'] = Variable<String>(eventId);
    return map;
  }

  HubPushLogCompanion toCompanion(bool nullToAbsent) {
    return HubPushLogCompanion(hubId: Value(hubId), eventId: Value(eventId));
  }

  factory HubPushRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HubPushRow(
      hubId: serializer.fromJson<String>(json['hubId']),
      eventId: serializer.fromJson<String>(json['eventId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'hubId': serializer.toJson<String>(hubId),
      'eventId': serializer.toJson<String>(eventId),
    };
  }

  HubPushRow copyWith({String? hubId, String? eventId}) =>
      HubPushRow(hubId: hubId ?? this.hubId, eventId: eventId ?? this.eventId);
  HubPushRow copyWithCompanion(HubPushLogCompanion data) {
    return HubPushRow(
      hubId: data.hubId.present ? data.hubId.value : this.hubId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HubPushRow(')
          ..write('hubId: $hubId, ')
          ..write('eventId: $eventId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(hubId, eventId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HubPushRow &&
          other.hubId == this.hubId &&
          other.eventId == this.eventId);
}

class HubPushLogCompanion extends UpdateCompanion<HubPushRow> {
  final Value<String> hubId;
  final Value<String> eventId;
  final Value<int> rowid;
  const HubPushLogCompanion({
    this.hubId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HubPushLogCompanion.insert({
    required String hubId,
    required String eventId,
    this.rowid = const Value.absent(),
  }) : hubId = Value(hubId),
       eventId = Value(eventId);
  static Insertable<HubPushRow> custom({
    Expression<String>? hubId,
    Expression<String>? eventId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (hubId != null) 'hub_id': hubId,
      if (eventId != null) 'event_id': eventId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HubPushLogCompanion copyWith({
    Value<String>? hubId,
    Value<String>? eventId,
    Value<int>? rowid,
  }) {
    return HubPushLogCompanion(
      hubId: hubId ?? this.hubId,
      eventId: eventId ?? this.eventId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (hubId.present) {
      map['hub_id'] = Variable<String>(hubId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HubPushLogCompanion(')
          ..write('hubId: $hubId, ')
          ..write('eventId: $eventId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SnapshotsTable extends Snapshots
    with TableInfo<$SnapshotsTable, SnapshotRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _asOfMeta = const VerificationMeta('asOf');
  @override
  late final GeneratedColumn<DateTime> asOf = GeneratedColumn<DateTime>(
    'as_of',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _upToEventIdMeta = const VerificationMeta(
    'upToEventId',
  );
  @override
  late final GeneratedColumn<String> upToEventId = GeneratedColumn<String>(
    'up_to_event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, asOf, upToEventId, state];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<SnapshotRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('as_of')) {
      context.handle(
        _asOfMeta,
        asOf.isAcceptableOrUnknown(data['as_of']!, _asOfMeta),
      );
    } else if (isInserting) {
      context.missing(_asOfMeta);
    }
    if (data.containsKey('up_to_event_id')) {
      context.handle(
        _upToEventIdMeta,
        upToEventId.isAcceptableOrUnknown(
          data['up_to_event_id']!,
          _upToEventIdMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SnapshotRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SnapshotRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      asOf: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}as_of'],
      )!,
      upToEventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}up_to_event_id'],
      ),
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
    );
  }

  @override
  $SnapshotsTable createAlias(String alias) {
    return $SnapshotsTable(attachedDatabase, alias);
  }
}

class SnapshotRow extends DataClass implements Insertable<SnapshotRow> {
  final int id;

  /// The read-time the snapshot was computed for.
  final DateTime asOf;

  /// The last event id folded into this snapshot (null = empty log).
  final String? upToEventId;

  /// Serialized derived state.
  final String state;
  const SnapshotRow({
    required this.id,
    required this.asOf,
    this.upToEventId,
    required this.state,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['as_of'] = Variable<DateTime>(asOf);
    if (!nullToAbsent || upToEventId != null) {
      map['up_to_event_id'] = Variable<String>(upToEventId);
    }
    map['state'] = Variable<String>(state);
    return map;
  }

  SnapshotsCompanion toCompanion(bool nullToAbsent) {
    return SnapshotsCompanion(
      id: Value(id),
      asOf: Value(asOf),
      upToEventId: upToEventId == null && nullToAbsent
          ? const Value.absent()
          : Value(upToEventId),
      state: Value(state),
    );
  }

  factory SnapshotRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SnapshotRow(
      id: serializer.fromJson<int>(json['id']),
      asOf: serializer.fromJson<DateTime>(json['asOf']),
      upToEventId: serializer.fromJson<String?>(json['upToEventId']),
      state: serializer.fromJson<String>(json['state']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'asOf': serializer.toJson<DateTime>(asOf),
      'upToEventId': serializer.toJson<String?>(upToEventId),
      'state': serializer.toJson<String>(state),
    };
  }

  SnapshotRow copyWith({
    int? id,
    DateTime? asOf,
    Value<String?> upToEventId = const Value.absent(),
    String? state,
  }) => SnapshotRow(
    id: id ?? this.id,
    asOf: asOf ?? this.asOf,
    upToEventId: upToEventId.present ? upToEventId.value : this.upToEventId,
    state: state ?? this.state,
  );
  SnapshotRow copyWithCompanion(SnapshotsCompanion data) {
    return SnapshotRow(
      id: data.id.present ? data.id.value : this.id,
      asOf: data.asOf.present ? data.asOf.value : this.asOf,
      upToEventId: data.upToEventId.present
          ? data.upToEventId.value
          : this.upToEventId,
      state: data.state.present ? data.state.value : this.state,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotRow(')
          ..write('id: $id, ')
          ..write('asOf: $asOf, ')
          ..write('upToEventId: $upToEventId, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, asOf, upToEventId, state);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SnapshotRow &&
          other.id == this.id &&
          other.asOf == this.asOf &&
          other.upToEventId == this.upToEventId &&
          other.state == this.state);
}

class SnapshotsCompanion extends UpdateCompanion<SnapshotRow> {
  final Value<int> id;
  final Value<DateTime> asOf;
  final Value<String?> upToEventId;
  final Value<String> state;
  const SnapshotsCompanion({
    this.id = const Value.absent(),
    this.asOf = const Value.absent(),
    this.upToEventId = const Value.absent(),
    this.state = const Value.absent(),
  });
  SnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime asOf,
    this.upToEventId = const Value.absent(),
    required String state,
  }) : asOf = Value(asOf),
       state = Value(state);
  static Insertable<SnapshotRow> custom({
    Expression<int>? id,
    Expression<DateTime>? asOf,
    Expression<String>? upToEventId,
    Expression<String>? state,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (asOf != null) 'as_of': asOf,
      if (upToEventId != null) 'up_to_event_id': upToEventId,
      if (state != null) 'state': state,
    });
  }

  SnapshotsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? asOf,
    Value<String?>? upToEventId,
    Value<String>? state,
  }) {
    return SnapshotsCompanion(
      id: id ?? this.id,
      asOf: asOf ?? this.asOf,
      upToEventId: upToEventId ?? this.upToEventId,
      state: state ?? this.state,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (asOf.present) {
      map['as_of'] = Variable<DateTime>(asOf.value);
    }
    if (upToEventId.present) {
      map['up_to_event_id'] = Variable<String>(upToEventId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('asOf: $asOf, ')
          ..write('upToEventId: $upToEventId, ')
          ..write('state: $state')
          ..write(')'))
        .toString();
  }
}

class $LocalSetupRowsTable extends LocalSetupRows
    with TableInfo<$LocalSetupRowsTable, LocalSetupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSetupRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timezoneMeta = const VerificationMeta(
    'timezone',
  );
  @override
  late final GeneratedColumn<String> timezone = GeneratedColumn<String>(
    'timezone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('America/Vancouver'),
  );
  static const VerificationMeta _user1IdMeta = const VerificationMeta(
    'user1Id',
  );
  @override
  late final GeneratedColumn<String> user1Id = GeneratedColumn<String>(
    'user1_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _user1NameMeta = const VerificationMeta(
    'user1Name',
  );
  @override
  late final GeneratedColumn<String> user1Name = GeneratedColumn<String>(
    'user1_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _user2IdMeta = const VerificationMeta(
    'user2Id',
  );
  @override
  late final GeneratedColumn<String> user2Id = GeneratedColumn<String>(
    'user2_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _user2NameMeta = const VerificationMeta(
    'user2Name',
  );
  @override
  late final GeneratedColumn<String> user2Name = GeneratedColumn<String>(
    'user2_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meUserIdMeta = const VerificationMeta(
    'meUserId',
  );
  @override
  late final GeneratedColumn<String> meUserId = GeneratedColumn<String>(
    'me_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    timezone,
    user1Id,
    user1Name,
    user2Id,
    user2Name,
    meUserId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_setup_rows';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSetupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('timezone')) {
      context.handle(
        _timezoneMeta,
        timezone.isAcceptableOrUnknown(data['timezone']!, _timezoneMeta),
      );
    }
    if (data.containsKey('user1_id')) {
      context.handle(
        _user1IdMeta,
        user1Id.isAcceptableOrUnknown(data['user1_id']!, _user1IdMeta),
      );
    } else if (isInserting) {
      context.missing(_user1IdMeta);
    }
    if (data.containsKey('user1_name')) {
      context.handle(
        _user1NameMeta,
        user1Name.isAcceptableOrUnknown(data['user1_name']!, _user1NameMeta),
      );
    } else if (isInserting) {
      context.missing(_user1NameMeta);
    }
    if (data.containsKey('user2_id')) {
      context.handle(
        _user2IdMeta,
        user2Id.isAcceptableOrUnknown(data['user2_id']!, _user2IdMeta),
      );
    } else if (isInserting) {
      context.missing(_user2IdMeta);
    }
    if (data.containsKey('user2_name')) {
      context.handle(
        _user2NameMeta,
        user2Name.isAcceptableOrUnknown(data['user2_name']!, _user2NameMeta),
      );
    } else if (isInserting) {
      context.missing(_user2NameMeta);
    }
    if (data.containsKey('me_user_id')) {
      context.handle(
        _meUserIdMeta,
        meUserId.isAcceptableOrUnknown(data['me_user_id']!, _meUserIdMeta),
      );
    } else if (isInserting) {
      context.missing(_meUserIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSetupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSetupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      timezone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}timezone'],
      )!,
      user1Id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user1_id'],
      )!,
      user1Name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user1_name'],
      )!,
      user2Id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user2_id'],
      )!,
      user2Name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user2_name'],
      )!,
      meUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}me_user_id'],
      )!,
    );
  }

  @override
  $LocalSetupRowsTable createAlias(String alias) {
    return $LocalSetupRowsTable(attachedDatabase, alias);
  }
}

class LocalSetupRow extends DataClass implements Insertable<LocalSetupRow> {
  /// Singleton row; always 0.
  final int id;
  final String timezone;
  final String user1Id;
  final String user1Name;
  final String user2Id;
  final String user2Name;

  /// The `userId` (either `user1Id` or `user2Id`) that this device represents.
  final String meUserId;
  const LocalSetupRow({
    required this.id,
    required this.timezone,
    required this.user1Id,
    required this.user1Name,
    required this.user2Id,
    required this.user2Name,
    required this.meUserId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['timezone'] = Variable<String>(timezone);
    map['user1_id'] = Variable<String>(user1Id);
    map['user1_name'] = Variable<String>(user1Name);
    map['user2_id'] = Variable<String>(user2Id);
    map['user2_name'] = Variable<String>(user2Name);
    map['me_user_id'] = Variable<String>(meUserId);
    return map;
  }

  LocalSetupRowsCompanion toCompanion(bool nullToAbsent) {
    return LocalSetupRowsCompanion(
      id: Value(id),
      timezone: Value(timezone),
      user1Id: Value(user1Id),
      user1Name: Value(user1Name),
      user2Id: Value(user2Id),
      user2Name: Value(user2Name),
      meUserId: Value(meUserId),
    );
  }

  factory LocalSetupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSetupRow(
      id: serializer.fromJson<int>(json['id']),
      timezone: serializer.fromJson<String>(json['timezone']),
      user1Id: serializer.fromJson<String>(json['user1Id']),
      user1Name: serializer.fromJson<String>(json['user1Name']),
      user2Id: serializer.fromJson<String>(json['user2Id']),
      user2Name: serializer.fromJson<String>(json['user2Name']),
      meUserId: serializer.fromJson<String>(json['meUserId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'timezone': serializer.toJson<String>(timezone),
      'user1Id': serializer.toJson<String>(user1Id),
      'user1Name': serializer.toJson<String>(user1Name),
      'user2Id': serializer.toJson<String>(user2Id),
      'user2Name': serializer.toJson<String>(user2Name),
      'meUserId': serializer.toJson<String>(meUserId),
    };
  }

  LocalSetupRow copyWith({
    int? id,
    String? timezone,
    String? user1Id,
    String? user1Name,
    String? user2Id,
    String? user2Name,
    String? meUserId,
  }) => LocalSetupRow(
    id: id ?? this.id,
    timezone: timezone ?? this.timezone,
    user1Id: user1Id ?? this.user1Id,
    user1Name: user1Name ?? this.user1Name,
    user2Id: user2Id ?? this.user2Id,
    user2Name: user2Name ?? this.user2Name,
    meUserId: meUserId ?? this.meUserId,
  );
  LocalSetupRow copyWithCompanion(LocalSetupRowsCompanion data) {
    return LocalSetupRow(
      id: data.id.present ? data.id.value : this.id,
      timezone: data.timezone.present ? data.timezone.value : this.timezone,
      user1Id: data.user1Id.present ? data.user1Id.value : this.user1Id,
      user1Name: data.user1Name.present ? data.user1Name.value : this.user1Name,
      user2Id: data.user2Id.present ? data.user2Id.value : this.user2Id,
      user2Name: data.user2Name.present ? data.user2Name.value : this.user2Name,
      meUserId: data.meUserId.present ? data.meUserId.value : this.meUserId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetupRow(')
          ..write('id: $id, ')
          ..write('timezone: $timezone, ')
          ..write('user1Id: $user1Id, ')
          ..write('user1Name: $user1Name, ')
          ..write('user2Id: $user2Id, ')
          ..write('user2Name: $user2Name, ')
          ..write('meUserId: $meUserId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    timezone,
    user1Id,
    user1Name,
    user2Id,
    user2Name,
    meUserId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSetupRow &&
          other.id == this.id &&
          other.timezone == this.timezone &&
          other.user1Id == this.user1Id &&
          other.user1Name == this.user1Name &&
          other.user2Id == this.user2Id &&
          other.user2Name == this.user2Name &&
          other.meUserId == this.meUserId);
}

class LocalSetupRowsCompanion extends UpdateCompanion<LocalSetupRow> {
  final Value<int> id;
  final Value<String> timezone;
  final Value<String> user1Id;
  final Value<String> user1Name;
  final Value<String> user2Id;
  final Value<String> user2Name;
  final Value<String> meUserId;
  const LocalSetupRowsCompanion({
    this.id = const Value.absent(),
    this.timezone = const Value.absent(),
    this.user1Id = const Value.absent(),
    this.user1Name = const Value.absent(),
    this.user2Id = const Value.absent(),
    this.user2Name = const Value.absent(),
    this.meUserId = const Value.absent(),
  });
  LocalSetupRowsCompanion.insert({
    this.id = const Value.absent(),
    this.timezone = const Value.absent(),
    required String user1Id,
    required String user1Name,
    required String user2Id,
    required String user2Name,
    required String meUserId,
  }) : user1Id = Value(user1Id),
       user1Name = Value(user1Name),
       user2Id = Value(user2Id),
       user2Name = Value(user2Name),
       meUserId = Value(meUserId);
  static Insertable<LocalSetupRow> custom({
    Expression<int>? id,
    Expression<String>? timezone,
    Expression<String>? user1Id,
    Expression<String>? user1Name,
    Expression<String>? user2Id,
    Expression<String>? user2Name,
    Expression<String>? meUserId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (timezone != null) 'timezone': timezone,
      if (user1Id != null) 'user1_id': user1Id,
      if (user1Name != null) 'user1_name': user1Name,
      if (user2Id != null) 'user2_id': user2Id,
      if (user2Name != null) 'user2_name': user2Name,
      if (meUserId != null) 'me_user_id': meUserId,
    });
  }

  LocalSetupRowsCompanion copyWith({
    Value<int>? id,
    Value<String>? timezone,
    Value<String>? user1Id,
    Value<String>? user1Name,
    Value<String>? user2Id,
    Value<String>? user2Name,
    Value<String>? meUserId,
  }) {
    return LocalSetupRowsCompanion(
      id: id ?? this.id,
      timezone: timezone ?? this.timezone,
      user1Id: user1Id ?? this.user1Id,
      user1Name: user1Name ?? this.user1Name,
      user2Id: user2Id ?? this.user2Id,
      user2Name: user2Name ?? this.user2Name,
      meUserId: meUserId ?? this.meUserId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (timezone.present) {
      map['timezone'] = Variable<String>(timezone.value);
    }
    if (user1Id.present) {
      map['user1_id'] = Variable<String>(user1Id.value);
    }
    if (user1Name.present) {
      map['user1_name'] = Variable<String>(user1Name.value);
    }
    if (user2Id.present) {
      map['user2_id'] = Variable<String>(user2Id.value);
    }
    if (user2Name.present) {
      map['user2_name'] = Variable<String>(user2Name.value);
    }
    if (meUserId.present) {
      map['me_user_id'] = Variable<String>(meUserId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSetupRowsCompanion(')
          ..write('id: $id, ')
          ..write('timezone: $timezone, ')
          ..write('user1Id: $user1Id, ')
          ..write('user1Name: $user1Name, ')
          ..write('user2Id: $user2Id, ')
          ..write('user2Name: $user2Name, ')
          ..write('meUserId: $meUserId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EventsTable events = $EventsTable(this);
  late final $HubCursorsTable hubCursors = $HubCursorsTable(this);
  late final $HubPushLogTable hubPushLog = $HubPushLogTable(this);
  late final $SnapshotsTable snapshots = $SnapshotsTable(this);
  late final $LocalSetupRowsTable localSetupRows = $LocalSetupRowsTable(this);
  late final EventsDao eventsDao = EventsDao(this as AppDatabase);
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  late final LocalSetupDao localSetupDao = LocalSetupDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    events,
    hubCursors,
    hubPushLog,
    snapshots,
    localSetupRows,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$EventsTableCreateCompanionBuilder =
    EventsCompanion Function({
      required String eventId,
      required String deviceId,
      required String userId,
      required String type,
      required DateTime occurredAt,
      required DateTime createdAt,
      required String payload,
      Value<int> rowid,
    });
typedef $$EventsTableUpdateCompanionBuilder =
    EventsCompanion Function({
      Value<String> eventId,
      Value<String> deviceId,
      Value<String> userId,
      Value<String> type,
      Value<DateTime> occurredAt,
      Value<DateTime> createdAt,
      Value<String> payload,
      Value<int> rowid,
    });

class $$EventsTableFilterComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EventsTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsTable> {
  $$EventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);
}

class $$EventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsTable,
          EventRow,
          $$EventsTableFilterComposer,
          $$EventsTableOrderingComposer,
          $$EventsTableAnnotationComposer,
          $$EventsTableCreateCompanionBuilder,
          $$EventsTableUpdateCompanionBuilder,
          (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
          EventRow,
          PrefetchHooks Function()
        > {
  $$EventsTableTableManager(_$AppDatabase db, $EventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion(
                eventId: eventId,
                deviceId: deviceId,
                userId: userId,
                type: type,
                occurredAt: occurredAt,
                createdAt: createdAt,
                payload: payload,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String deviceId,
                required String userId,
                required String type,
                required DateTime occurredAt,
                required DateTime createdAt,
                required String payload,
                Value<int> rowid = const Value.absent(),
              }) => EventsCompanion.insert(
                eventId: eventId,
                deviceId: deviceId,
                userId: userId,
                type: type,
                occurredAt: occurredAt,
                createdAt: createdAt,
                payload: payload,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsTable,
      EventRow,
      $$EventsTableFilterComposer,
      $$EventsTableOrderingComposer,
      $$EventsTableAnnotationComposer,
      $$EventsTableCreateCompanionBuilder,
      $$EventsTableUpdateCompanionBuilder,
      (EventRow, BaseReferences<_$AppDatabase, $EventsTable, EventRow>),
      EventRow,
      PrefetchHooks Function()
    >;
typedef $$HubCursorsTableCreateCompanionBuilder =
    HubCursorsCompanion Function({
      required String hubId,
      Value<int> lastPulledSeq,
      Value<int> rowid,
    });
typedef $$HubCursorsTableUpdateCompanionBuilder =
    HubCursorsCompanion Function({
      Value<String> hubId,
      Value<int> lastPulledSeq,
      Value<int> rowid,
    });

class $$HubCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $HubCursorsTable> {
  $$HubCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hubId => $composableBuilder(
    column: $table.hubId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HubCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $HubCursorsTable> {
  $$HubCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hubId => $composableBuilder(
    column: $table.hubId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HubCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HubCursorsTable> {
  $$HubCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hubId =>
      $composableBuilder(column: $table.hubId, builder: (column) => column);

  GeneratedColumn<int> get lastPulledSeq => $composableBuilder(
    column: $table.lastPulledSeq,
    builder: (column) => column,
  );
}

class $$HubCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HubCursorsTable,
          HubCursorRow,
          $$HubCursorsTableFilterComposer,
          $$HubCursorsTableOrderingComposer,
          $$HubCursorsTableAnnotationComposer,
          $$HubCursorsTableCreateCompanionBuilder,
          $$HubCursorsTableUpdateCompanionBuilder,
          (
            HubCursorRow,
            BaseReferences<_$AppDatabase, $HubCursorsTable, HubCursorRow>,
          ),
          HubCursorRow,
          PrefetchHooks Function()
        > {
  $$HubCursorsTableTableManager(_$AppDatabase db, $HubCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HubCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HubCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HubCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hubId = const Value.absent(),
                Value<int> lastPulledSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HubCursorsCompanion(
                hubId: hubId,
                lastPulledSeq: lastPulledSeq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hubId,
                Value<int> lastPulledSeq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HubCursorsCompanion.insert(
                hubId: hubId,
                lastPulledSeq: lastPulledSeq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HubCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HubCursorsTable,
      HubCursorRow,
      $$HubCursorsTableFilterComposer,
      $$HubCursorsTableOrderingComposer,
      $$HubCursorsTableAnnotationComposer,
      $$HubCursorsTableCreateCompanionBuilder,
      $$HubCursorsTableUpdateCompanionBuilder,
      (
        HubCursorRow,
        BaseReferences<_$AppDatabase, $HubCursorsTable, HubCursorRow>,
      ),
      HubCursorRow,
      PrefetchHooks Function()
    >;
typedef $$HubPushLogTableCreateCompanionBuilder =
    HubPushLogCompanion Function({
      required String hubId,
      required String eventId,
      Value<int> rowid,
    });
typedef $$HubPushLogTableUpdateCompanionBuilder =
    HubPushLogCompanion Function({
      Value<String> hubId,
      Value<String> eventId,
      Value<int> rowid,
    });

class $$HubPushLogTableFilterComposer
    extends Composer<_$AppDatabase, $HubPushLogTable> {
  $$HubPushLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get hubId => $composableBuilder(
    column: $table.hubId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HubPushLogTableOrderingComposer
    extends Composer<_$AppDatabase, $HubPushLogTable> {
  $$HubPushLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get hubId => $composableBuilder(
    column: $table.hubId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HubPushLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $HubPushLogTable> {
  $$HubPushLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get hubId =>
      $composableBuilder(column: $table.hubId, builder: (column) => column);

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);
}

class $$HubPushLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HubPushLogTable,
          HubPushRow,
          $$HubPushLogTableFilterComposer,
          $$HubPushLogTableOrderingComposer,
          $$HubPushLogTableAnnotationComposer,
          $$HubPushLogTableCreateCompanionBuilder,
          $$HubPushLogTableUpdateCompanionBuilder,
          (
            HubPushRow,
            BaseReferences<_$AppDatabase, $HubPushLogTable, HubPushRow>,
          ),
          HubPushRow,
          PrefetchHooks Function()
        > {
  $$HubPushLogTableTableManager(_$AppDatabase db, $HubPushLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HubPushLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HubPushLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HubPushLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> hubId = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HubPushLogCompanion(
                hubId: hubId,
                eventId: eventId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String hubId,
                required String eventId,
                Value<int> rowid = const Value.absent(),
              }) => HubPushLogCompanion.insert(
                hubId: hubId,
                eventId: eventId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HubPushLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HubPushLogTable,
      HubPushRow,
      $$HubPushLogTableFilterComposer,
      $$HubPushLogTableOrderingComposer,
      $$HubPushLogTableAnnotationComposer,
      $$HubPushLogTableCreateCompanionBuilder,
      $$HubPushLogTableUpdateCompanionBuilder,
      (HubPushRow, BaseReferences<_$AppDatabase, $HubPushLogTable, HubPushRow>),
      HubPushRow,
      PrefetchHooks Function()
    >;
typedef $$SnapshotsTableCreateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      required DateTime asOf,
      Value<String?> upToEventId,
      required String state,
    });
typedef $$SnapshotsTableUpdateCompanionBuilder =
    SnapshotsCompanion Function({
      Value<int> id,
      Value<DateTime> asOf,
      Value<String?> upToEventId,
      Value<String> state,
    });

class $$SnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get upToEventId => $composableBuilder(
    column: $table.upToEventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get asOf => $composableBuilder(
    column: $table.asOf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get upToEventId => $composableBuilder(
    column: $table.upToEventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SnapshotsTable> {
  $$SnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get asOf =>
      $composableBuilder(column: $table.asOf, builder: (column) => column);

  GeneratedColumn<String> get upToEventId => $composableBuilder(
    column: $table.upToEventId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);
}

class $$SnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SnapshotsTable,
          SnapshotRow,
          $$SnapshotsTableFilterComposer,
          $$SnapshotsTableOrderingComposer,
          $$SnapshotsTableAnnotationComposer,
          $$SnapshotsTableCreateCompanionBuilder,
          $$SnapshotsTableUpdateCompanionBuilder,
          (
            SnapshotRow,
            BaseReferences<_$AppDatabase, $SnapshotsTable, SnapshotRow>,
          ),
          SnapshotRow,
          PrefetchHooks Function()
        > {
  $$SnapshotsTableTableManager(_$AppDatabase db, $SnapshotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> asOf = const Value.absent(),
                Value<String?> upToEventId = const Value.absent(),
                Value<String> state = const Value.absent(),
              }) => SnapshotsCompanion(
                id: id,
                asOf: asOf,
                upToEventId: upToEventId,
                state: state,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime asOf,
                Value<String?> upToEventId = const Value.absent(),
                required String state,
              }) => SnapshotsCompanion.insert(
                id: id,
                asOf: asOf,
                upToEventId: upToEventId,
                state: state,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SnapshotsTable,
      SnapshotRow,
      $$SnapshotsTableFilterComposer,
      $$SnapshotsTableOrderingComposer,
      $$SnapshotsTableAnnotationComposer,
      $$SnapshotsTableCreateCompanionBuilder,
      $$SnapshotsTableUpdateCompanionBuilder,
      (
        SnapshotRow,
        BaseReferences<_$AppDatabase, $SnapshotsTable, SnapshotRow>,
      ),
      SnapshotRow,
      PrefetchHooks Function()
    >;
typedef $$LocalSetupRowsTableCreateCompanionBuilder =
    LocalSetupRowsCompanion Function({
      Value<int> id,
      Value<String> timezone,
      required String user1Id,
      required String user1Name,
      required String user2Id,
      required String user2Name,
      required String meUserId,
    });
typedef $$LocalSetupRowsTableUpdateCompanionBuilder =
    LocalSetupRowsCompanion Function({
      Value<int> id,
      Value<String> timezone,
      Value<String> user1Id,
      Value<String> user1Name,
      Value<String> user2Id,
      Value<String> user2Name,
      Value<String> meUserId,
    });

class $$LocalSetupRowsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSetupRowsTable> {
  $$LocalSetupRowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get user1Id => $composableBuilder(
    column: $table.user1Id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get user1Name => $composableBuilder(
    column: $table.user1Name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get user2Id => $composableBuilder(
    column: $table.user2Id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get user2Name => $composableBuilder(
    column: $table.user2Name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get meUserId => $composableBuilder(
    column: $table.meUserId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSetupRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSetupRowsTable> {
  $$LocalSetupRowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timezone => $composableBuilder(
    column: $table.timezone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get user1Id => $composableBuilder(
    column: $table.user1Id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get user1Name => $composableBuilder(
    column: $table.user1Name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get user2Id => $composableBuilder(
    column: $table.user2Id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get user2Name => $composableBuilder(
    column: $table.user2Name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get meUserId => $composableBuilder(
    column: $table.meUserId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSetupRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSetupRowsTable> {
  $$LocalSetupRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get timezone =>
      $composableBuilder(column: $table.timezone, builder: (column) => column);

  GeneratedColumn<String> get user1Id =>
      $composableBuilder(column: $table.user1Id, builder: (column) => column);

  GeneratedColumn<String> get user1Name =>
      $composableBuilder(column: $table.user1Name, builder: (column) => column);

  GeneratedColumn<String> get user2Id =>
      $composableBuilder(column: $table.user2Id, builder: (column) => column);

  GeneratedColumn<String> get user2Name =>
      $composableBuilder(column: $table.user2Name, builder: (column) => column);

  GeneratedColumn<String> get meUserId =>
      $composableBuilder(column: $table.meUserId, builder: (column) => column);
}

class $$LocalSetupRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSetupRowsTable,
          LocalSetupRow,
          $$LocalSetupRowsTableFilterComposer,
          $$LocalSetupRowsTableOrderingComposer,
          $$LocalSetupRowsTableAnnotationComposer,
          $$LocalSetupRowsTableCreateCompanionBuilder,
          $$LocalSetupRowsTableUpdateCompanionBuilder,
          (
            LocalSetupRow,
            BaseReferences<_$AppDatabase, $LocalSetupRowsTable, LocalSetupRow>,
          ),
          LocalSetupRow,
          PrefetchHooks Function()
        > {
  $$LocalSetupRowsTableTableManager(
    _$AppDatabase db,
    $LocalSetupRowsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSetupRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSetupRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSetupRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                Value<String> user1Id = const Value.absent(),
                Value<String> user1Name = const Value.absent(),
                Value<String> user2Id = const Value.absent(),
                Value<String> user2Name = const Value.absent(),
                Value<String> meUserId = const Value.absent(),
              }) => LocalSetupRowsCompanion(
                id: id,
                timezone: timezone,
                user1Id: user1Id,
                user1Name: user1Name,
                user2Id: user2Id,
                user2Name: user2Name,
                meUserId: meUserId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> timezone = const Value.absent(),
                required String user1Id,
                required String user1Name,
                required String user2Id,
                required String user2Name,
                required String meUserId,
              }) => LocalSetupRowsCompanion.insert(
                id: id,
                timezone: timezone,
                user1Id: user1Id,
                user1Name: user1Name,
                user2Id: user2Id,
                user2Name: user2Name,
                meUserId: meUserId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSetupRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSetupRowsTable,
      LocalSetupRow,
      $$LocalSetupRowsTableFilterComposer,
      $$LocalSetupRowsTableOrderingComposer,
      $$LocalSetupRowsTableAnnotationComposer,
      $$LocalSetupRowsTableCreateCompanionBuilder,
      $$LocalSetupRowsTableUpdateCompanionBuilder,
      (
        LocalSetupRow,
        BaseReferences<_$AppDatabase, $LocalSetupRowsTable, LocalSetupRow>,
      ),
      LocalSetupRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EventsTableTableManager get events =>
      $$EventsTableTableManager(_db, _db.events);
  $$HubCursorsTableTableManager get hubCursors =>
      $$HubCursorsTableTableManager(_db, _db.hubCursors);
  $$HubPushLogTableTableManager get hubPushLog =>
      $$HubPushLogTableTableManager(_db, _db.hubPushLog);
  $$SnapshotsTableTableManager get snapshots =>
      $$SnapshotsTableTableManager(_db, _db.snapshots);
  $$LocalSetupRowsTableTableManager get localSetupRows =>
      $$LocalSetupRowsTableTableManager(_db, _db.localSetupRows);
}
