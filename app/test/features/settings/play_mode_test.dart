/// Per-person play mode (Standard / Adventure) and the Adventure home screen
/// (Hall / Ledger): persistence through the real event log and switching in
/// both directions without losing any game state.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lootlog/data/actions.dart';
import 'package:lootlog/data/blobs/blob_store.dart';
import 'package:lootlog/data/db/database.dart';
import 'package:lootlog/domain/event.dart';
import 'package:lootlog/domain/value_types.dart';
import 'package:lootlog/features/settings/play_mode.dart';
import 'package:lootlog/features/settings/play_mode_providers.dart';

void main() {
  late AppDatabase db;
  late HouseholdActions alex;
  late HouseholdActions sam;
  var clock = DateTime.utc(2026, 10, 3, 12);

  /// A strictly advancing clock so toggles never tie on occurredAt.
  DateTime tick() => clock = clock.add(const Duration(seconds: 1));

  HouseholdActions actionsFor(String userId) => HouseholdActions(
        db: db,
        blobs: BlobStore(Directory.systemTemp.createTempSync('lootlog_play')),
        deviceId: 'dev-$userId',
        meUserId: userId,
      );

  Future<PlayPrefs> prefsOf(String userId) async =>
      resolvePlayPrefs(await db.eventsDao.allEvents(), userId);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    alex = actionsFor('alex');
    sam = actionsFor('sam');
  });

  tearDown(() => db.close());

  group('defaults', () {
    test('an empty log is Adventure, opening on the Hall', () {
      final prefs = resolvePlayPrefs(const [], 'alex');
      expect(prefs.mode, PlayMode.adventure);
      expect(prefs.home, AdventureHome.hall);
      expect(homeDestination(prefs), HomeDestination.hall);
    });

    test("a device's legacy Classic skin choice is the fallback until the "
        'person chooses a mode', () async {
      expect(
          resolvePlayPrefs(const [], 'alex', fallbackMode: PlayMode.standard)
              .mode,
          PlayMode.standard);

      await setPlayMode(alex, PlayMode.adventure, at: tick());
      expect(
          resolvePlayPrefs(await db.eventsDao.allEvents(), 'alex',
                  fallbackMode: PlayMode.standard)
              .mode,
          PlayMode.adventure,
          reason: 'an explicit choice always beats the legacy device skin');
    });
  });

  group('persistence', () {
    test('a chosen mode and home survive a reload from the database',
        () async {
      await setAdventureHome(alex, AdventureHome.ledger, at: tick());
      await setPlayMode(sam, PlayMode.standard, at: tick());

      // A fresh read of the stored log — what the next launch sees.
      expect((await prefsOf('alex')).home, AdventureHome.ledger);
      expect((await prefsOf('sam')).mode, PlayMode.standard);
    });

    test('the setting is per person: one adult choosing Standard leaves '
        'the other in Adventure', () async {
      await setPlayMode(sam, PlayMode.standard, at: tick());

      expect((await prefsOf('sam')).mode, PlayMode.standard);
      expect((await prefsOf('alex')).mode, PlayMode.adventure);

      await setAdventureHome(sam, AdventureHome.ledger, at: tick());
      expect((await prefsOf('alex')).home, AdventureHome.hall);
    });

    test('unrecognised stored values are ignored, never crash', () {
      final now = DateTime.utc(2026, 10, 3);
      final log = [
        CosmeticSet(
          eventId: 'a',
          deviceId: 'd',
          userId: 'alex',
          occurredAt: now,
          createdAt: now,
          key: playModeKey('alex'),
          value: 'adventure',
        ),
        CosmeticSet(
          eventId: 'b',
          deviceId: 'd',
          userId: 'alex',
          occurredAt: now.add(const Duration(seconds: 1)),
          createdAt: now,
          key: playModeKey('alex'),
          value: 'speedrun',
        ),
        CosmeticSet(
          eventId: 'c',
          deviceId: 'd',
          userId: 'alex',
          occurredAt: now,
          createdAt: now,
          key: adventureHomeKey('alex'),
          value: 42,
        ),
      ];
      final prefs = resolvePlayPrefs(log, 'alex');
      expect(prefs.mode, PlayMode.adventure);
      expect(prefs.home, AdventureHome.hall);
    });

    test('the latest setting wins by (occurredAt, eventId), not log order',
        () {
      final t = DateTime.utc(2026, 10, 3);
      CosmeticSet mode(String id, DateTime at, PlayMode m) => CosmeticSet(
            eventId: id,
            deviceId: 'd',
            userId: 'alex',
            occurredAt: at,
            createdAt: at,
            key: playModeKey('alex'),
            value: m.name,
          );
      // A synced older event arriving after a newer one must not win.
      final log = [
        mode('2', t.add(const Duration(minutes: 1)), PlayMode.adventure),
        mode('1', t, PlayMode.standard),
      ];
      expect(resolvePlayPrefs(log, 'alex').mode, PlayMode.adventure);
    });
  });

  group('switching', () {
    test('Adventure -> Standard -> Adventure keeps every game event and '
        'restores the home choice', () async {
      await setAdventureHome(alex, AdventureHome.ledger, at: tick());

      // Some game state accumulated while in Adventure.
      final now = tick();
      await alex.append(GameRewardGranted(
        eventId: 'reward-1',
        deviceId: 'dev-alex',
        userId: 'alex',
        occurredAt: now,
        createdAt: now,
        rewardId: 'streak:7',
        kind: RewardKind.title,
        sourceRef: 'streak',
        grantedAt: now,
      ));
      final before = await db.eventsDao.allEvents();

      await setPlayMode(alex, PlayMode.standard, at: tick());
      var prefs = await prefsOf('alex');
      expect(prefs.mode, PlayMode.standard);
      expect(homeDestination(prefs), HomeDestination.ledger);

      await setPlayMode(alex, PlayMode.adventure, at: tick());
      prefs = await prefsOf('alex');
      expect(prefs.mode, PlayMode.adventure);
      expect(prefs.home, AdventureHome.ledger,
          reason: 'switching back restores the earlier home choice');

      // Nothing was removed: every earlier event is still in the log.
      final after = await db.eventsDao.allEvents();
      expect(after.map((e) => e.eventId),
          containsAll(before.map((e) => e.eventId)));
      expect(after.whereType<GameRewardGranted>().single.rewardId, 'streak:7');
    });

    test('Standard -> Adventure -> Standard -> Adventure, landing on the '
        'default Hall home each time', () async {
      await setPlayMode(alex, PlayMode.standard, at: tick());
      expect(homeDestination(await prefsOf('alex')), HomeDestination.ledger);

      await setPlayMode(alex, PlayMode.adventure, at: tick());
      expect(homeDestination(await prefsOf('alex')), HomeDestination.hall);

      await setPlayMode(alex, PlayMode.standard, at: tick());
      expect((await prefsOf('alex')).mode, PlayMode.standard);

      await setPlayMode(alex, PlayMode.adventure, at: tick());
      expect(homeDestination(await prefsOf('alex')), HomeDestination.hall);
    });
  });

  group('homeDestination', () {
    test('only Adventure with the Hall home opens the hall', () {
      expect(
          homeDestination(const PlayPrefs(
              mode: PlayMode.standard, home: AdventureHome.hall)),
          HomeDestination.ledger);
      expect(
          homeDestination(const PlayPrefs(
              mode: PlayMode.adventure, home: AdventureHome.hall)),
          HomeDestination.hall);
      expect(
          homeDestination(const PlayPrefs(
              mode: PlayMode.adventure, home: AdventureHome.ledger)),
          HomeDestination.ledger);
    });
  });
}
