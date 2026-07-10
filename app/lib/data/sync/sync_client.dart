/// The multi-hub sync client: one device's side of LAN convergence.
///
/// A device may be paired with several hubs and keeps an independent pull cursor
/// per hub (see [SyncDao]). Each cycle, for every reachable paired hub, the
/// client pushes its un-pushed events and referenced blobs, then pulls new
/// events and any blobs they reference. Everything is idempotent — events by
/// `eventId`, blobs by content hash — so partial cycles, retries, and
/// multi-hub overlap all converge with no conflict logic.
///
/// Failures are silent-but-visible: an unreachable hub yields a [HubSyncResult]
/// with an `error`, never an exception that blocks the app.
library;

// Blob IO is intentionally async so it never blocks the UI isolate.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';

import '../blobs/blob_store.dart';
import '../db/database.dart';
import 'wire.dart';

/// Per-hub outcome of a sync cycle, aggregated into a [SyncResult].
class HubSyncResult {
  const HubSyncResult({
    required this.hubId,
    required this.pushed,
    required this.pulled,
    required this.blobsPushed,
    required this.blobsPulled,
    this.error,
  });

  const HubSyncResult.failed(this.hubId, this.error)
      : pushed = 0,
        pulled = 0,
        blobsPushed = 0,
        blobsPulled = 0;

  final String hubId;
  final int pushed;
  final int pulled;
  final int blobsPushed;
  final int blobsPulled;
  final String? error;

  bool get ok => error == null;
}

/// Aggregate outcome of one [SyncClient.syncOnce] across all paired hubs.
class SyncResult {
  const SyncResult(this.hubs);

  final List<HubSyncResult> hubs;

  bool get allOk => hubs.every((h) => h.ok);
  int get pulled => hubs.fold(0, (a, h) => a + h.pulled);
  int get pushed => hubs.fold(0, (a, h) => a + h.pushed);
}

/// Drives sync for one device against its paired hubs.
class SyncClient {
  SyncClient({
    required this.db,
    required this.blobs,
    required this.deviceName,
    this.pullExclusions,
    HttpClient? httpClient,
  }) : _http = httpClient ?? HttpClient();

  final AppDatabase db;
  final BlobStore blobs;

  /// Display name announced to a hub at pairing.
  final String deviceName;

  /// Blob hashes to skip when pulling — the receipts this device deliberately
  /// offloaded, so a pull cycle never re-downloads what offloading removed.
  final Future<Set<String>> Function()? pullExclusions;

  final HttpClient _http;

  /// Releases the underlying HTTP client. Call when disposing the sync service.
  void close() => _http.close(force: true);

  /// Pairs with the hub reachable at [baseUrl] using [pairingSecret], persisting
  /// the returned token so future cycles include this hub. Returns its hubId.
  Future<String> pair(String baseUrl, String pairingSecret) async {
    final res = await _send(
      'POST',
      _uri(baseUrl, 'pair'),
      body: {'pairingSecret': pairingSecret, 'deviceName': deviceName},
    );
    if (res.status != 200) {
      throw SyncException('pair failed (${res.status}): ${res.text}');
    }
    final pr = PairResult.fromJson(
      (jsonDecode(res.text) as Map).cast<String, dynamic>(),
    );
    await db.pairedHubDao.upsert(
      PairedHubRow(
        hubId: pr.hubId,
        baseUrl: baseUrl,
        deviceToken: pr.deviceToken,
        name: _hostLabel(baseUrl),
      ),
    );
    return pr.hubId;
  }

  /// Runs one sync cycle against every paired hub, returning the outcome.
  Future<SyncResult> syncOnce() async {
    final hubs = await db.pairedHubDao.all();
    final results = <HubSyncResult>[];
    for (final hub in hubs) {
      results.add(await _syncHub(hub));
    }
    return SyncResult(results);
  }

  Future<HubSyncResult> _syncHub(PairedHubRow hub) async {
    try {
      final pushed = await _pushEvents(hub);
      final blobsPushed = await _pushBlobs(hub);
      final pulled = await _pullEvents(hub);
      final blobsPulled = await _pullBlobs(hub);
      return HubSyncResult(
        hubId: hub.hubId,
        pushed: pushed,
        pulled: pulled,
        blobsPushed: blobsPushed,
        blobsPulled: blobsPulled,
      );
    } on Object catch (e) {
      // Silent-but-visible: surface the failure without throwing.
      return HubSyncResult.failed(hub.hubId, e.toString());
    }
  }

  // ---- push ---------------------------------------------------------------

  Future<int> _pushEvents(PairedHubRow hub) async {
    final unpushed = await db.syncDao.unpushedEventsForHub(hub.hubId);
    if (unpushed.isEmpty) return 0;
    final res = await _send(
      'POST',
      _uri(hub.baseUrl, 'events'),
      token: hub.deviceToken,
      body: {'events': [for (final e in unpushed) e.toJson()]},
    );
    if (res.status != 200) {
      throw SyncException('push events failed (${res.status})');
    }
    await db.syncDao.markPushed(hub.hubId, [for (final e in unpushed) e.eventId]);
    return unpushed.length;
  }

  Future<int> _pushBlobs(PairedHubRow hub) async {
    final referenced = BlobStore.referencedBlobs(await db.eventsDao.allEvents());
    var count = 0;
    for (final sha in referenced) {
      if (!await blobs.exists(sha)) continue; // we don't hold it (yet)
      // Skip the PUT when the hub already has it.
      final head = await _sendBytes('HEAD', _uri(hub.baseUrl, 'blobs/$sha'),
          token: hub.deviceToken);
      if (head.status == 200) continue;
      final bytes = await blobs.read(sha);
      final put = await _sendBytes('PUT', _uri(hub.baseUrl, 'blobs/$sha'),
          token: hub.deviceToken, bytes: bytes);
      if (put.status != 200) {
        throw SyncException('push blob $sha failed (${put.status})');
      }
      count++;
    }
    return count;
  }

  // ---- pull ---------------------------------------------------------------

  Future<int> _pullEvents(PairedHubRow hub) async {
    var cursor = await db.syncDao.pullCursor(hub.hubId);
    var total = 0;
    while (true) {
      final res = await _send('GET',
          _uri(hub.baseUrl, 'events', {'after': '$cursor', 'limit': '500'}),
          token: hub.deviceToken);
      if (res.status != 200) {
        throw SyncException('pull events failed (${res.status})');
      }
      final page = EventPage.fromJson(
        (jsonDecode(res.text) as Map).cast<String, dynamic>(),
      );
      if (page.events.isNotEmpty) {
        await db.eventsDao.appendEvents(page.events);
        // Events pulled from a hub are, by definition, already known to it — so
        // never bounce them back on the next push.
        await db.syncDao
            .markPushed(hub.hubId, [for (final e in page.events) e.eventId]);
        total += page.events.length;
      }
      await db.syncDao.setPullCursor(hub.hubId, page.cursor);
      cursor = page.cursor;
      if (page.events.length < 500) break; // caught up
    }
    return total;
  }

  Future<int> _pullBlobs(PairedHubRow hub) async {
    final referenced = BlobStore.referencedBlobs(await db.eventsDao.allEvents());
    final excluded = await pullExclusions?.call() ?? const <String>{};
    var count = 0;
    for (final sha in referenced) {
      if (excluded.contains(sha)) continue;
      if (await blobs.exists(sha)) continue;
      final res = await _sendBytes('GET', _uri(hub.baseUrl, 'blobs/$sha'),
          token: hub.deviceToken);
      if (res.status == 404) continue; // this hub doesn't have it either
      if (res.status != 200) {
        throw SyncException('pull blob $sha failed (${res.status})');
      }
      await blobs.save(res.bytes);
      count++;
    }
    return count;
  }

  // ---- offload support ------------------------------------------------------

  /// The subset of [shas] that EVERY paired hub confirms holding (HEAD 200).
  /// An unreachable hub, a failed check, or an empty hub list confirms
  /// nothing, so offloading only ever errs on the side of keeping the local
  /// copy. Never throws.
  Future<Set<String>> confirmBlobsOnAllHubs(Set<String> shas) async {
    if (shas.isEmpty) return {};
    final hubs = await db.pairedHubDao.all();
    if (hubs.isEmpty) return {};
    var confirmed = Set<String>.of(shas);
    for (final hub in hubs) {
      final onThisHub = <String>{};
      for (final sha in confirmed) {
        try {
          final head = await _sendBytes(
              'HEAD', _uri(hub.baseUrl, 'blobs/$sha'),
              token: hub.deviceToken);
          if (head.status == 200) onThisHub.add(sha);
        } on Object {
          // Treat as not confirmed on this hub.
        }
      }
      confirmed = confirmed.intersection(onThisHub);
      if (confirmed.isEmpty) break;
    }
    return confirmed;
  }

  /// Fetches [sha] from the first paired hub that has it, saving it locally.
  /// Returns true on success. Never throws.
  Future<bool> fetchBlob(String sha) async {
    for (final hub in await db.pairedHubDao.all()) {
      try {
        final res = await _sendBytes('GET', _uri(hub.baseUrl, 'blobs/$sha'),
            token: hub.deviceToken);
        if (res.status == 200) {
          await blobs.save(res.bytes);
          return true;
        }
      } on Object {
        // Try the next hub.
      }
    }
    return false;
  }

  // ---- transport ----------------------------------------------------------

  Uri _uri(String baseUrl, String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path.replaceAll(RegExp(r'/$'), '')}/$path',
      queryParameters: query,
    );
  }

  Future<_Res> _send(String method, Uri uri,
      {String? token, Map<String, dynamic>? body}) async {
    final req = await _http.openUrl(method, uri);
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (body != null) {
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode(body)));
    }
    final resp = await req.close();
    final text = await resp.transform(utf8.decoder).join();
    return _Res(resp.statusCode, text, const []);
  }

  Future<_Res> _sendBytes(String method, Uri uri,
      {String? token, List<int>? bytes}) async {
    final req = await _http.openUrl(method, uri);
    if (token != null) req.headers.set('authorization', 'Bearer $token');
    if (bytes != null) {
      req.headers.contentType = ContentType.binary;
      req.add(bytes);
    }
    final resp = await req.close();
    final out = <int>[];
    await for (final chunk in resp) {
      out.addAll(chunk);
    }
    return _Res(resp.statusCode, '', out);
  }

  String _hostLabel(String baseUrl) {
    final u = Uri.tryParse(baseUrl);
    return u == null ? baseUrl : '${u.host}:${u.port}';
  }
}

class _Res {
  const _Res(this.status, this.text, this.bytes);
  final int status;
  final String text;
  final List<int> bytes;
}

/// A hub returned an unexpected status during sync. Caught per-hub and surfaced
/// as a [HubSyncResult] error, never propagated to the UI.
class SyncException implements Exception {
  const SyncException(this.message);
  final String message;
  @override
  String toString() => 'SyncException: $message';
}
