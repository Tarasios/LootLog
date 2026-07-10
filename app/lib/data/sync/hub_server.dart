/// The LAN sync hub: a small `package:shelf` HTTP server any desktop build can
/// host so phones (and the other desktop) converge over the local network.
///
/// The hub is stateless merge logic on top of the same append-only store the
/// app already uses. Events are idempotent by `eventId`; blobs are
/// content-addressed and hash-verified; convergence needs no conflict handling.
/// Each hub assigns its own monotonic `seq` (see [HubHostDao]) so every paired
/// device keeps an independent, resumable cursor.
///
/// Endpoints (all but `/pair` require `Authorization: Bearer <deviceToken>`):
///   * `POST /pair`            {pairingSecret, deviceName} -> {hubId, deviceToken}
///   * `POST /events`          {events:[envelope…]} -> {maxSeq} (idempotent batch)
///   * `GET  /events?after=&limit=` -> {events:[…], maxSeq}
///   * `PUT  /blobs/<sha256>`  raw bytes (hash-verified, 20 MB cap) -> 200
///   * `GET  /blobs/<sha256>`  raw bytes | 404
///   * `HEAD /blobs/<sha256>`  200 | 404 (lets a client skip a re-PUT)
library;

// Blob IO here is intentionally async; the sync isolate never blocks the UI.
// ignore_for_file: avoid_slow_async_io

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../domain/event.dart';
import '../../domain/ids.dart';
import '../blobs/blob_store.dart';
import '../db/database.dart';
import 'wire.dart';

/// A hosted LootLog sync hub bound to one device's [AppDatabase] and
/// [BlobStore]. Construct it, `await ready`, then either mount [handler] in a
/// larger server or call [serve] to bind a socket.
class HubServer {
  HubServer({
    required this.db,
    required this.blobs,
    String? hubId,
    String? pairingSecret,
  })  : _pinnedHubId = hubId,
        _pinnedPairingSecret = pairingSecret;

  final AppDatabase db;
  final BlobStore blobs;
  final String? _pinnedHubId;
  final String? _pinnedPairingSecret;

  late final String hubId;
  late final String pairingSecret;
  bool _ready = false;

  /// Ensures the hub identity exists (generating it once) before serving.
  Future<void> ready() async {
    if (_ready) return;
    final cfg = await db.hubHostDao.ensureConfig(
      hubId: _pinnedHubId,
      pairingSecret: _pinnedPairingSecret,
    );
    hubId = cfg.hubId;
    pairingSecret = cfg.pairingSecret;
    await db.hubHostDao.assignSeqs();
    _ready = true;
  }

  /// Binds an [HttpServer] on [host]:[port]. Pass port 0 to let the OS choose;
  /// read the returned server's `.port` for the actual value.
  Future<HttpServer> serve({Object host = '127.0.0.1', int port = 0}) async {
    await ready();
    return shelf_io.serve(handler, host, port);
  }

  /// The request handler, usable directly in tests without binding a socket.
  Handler get handler => _dispatch;

  Future<Response> _dispatch(Request request) async {
    await ready();
    final segments = request.url.pathSegments;
    final method = request.method;

    try {
      // Pairing is the only unauthenticated route.
      if (method == 'POST' && _isPath(segments, ['pair'])) {
        return await _handlePair(request);
      }

      final authed = await _authorized(request);
      if (!authed) {
        return _json(401, {'error': 'unauthorized'});
      }

      if (_isPath(segments, ['events'])) {
        if (method == 'POST') return await _handlePostEvents(request);
        if (method == 'GET') return await _handleGetEvents(request);
      }
      if (segments.length == 2 && segments[0] == 'blobs') {
        final sha = segments[1];
        if (method == 'PUT') return await _handlePutBlob(request, sha);
        if (method == 'GET') return await _handleGetBlob(sha, head: false);
        if (method == 'HEAD') return await _handleGetBlob(sha, head: true);
      }
      return _json(404, {'error': 'not found'});
    } on FormatException catch (e) {
      return _json(400, {'error': 'bad request', 'detail': e.message});
    }
  }

  // ---- routes -------------------------------------------------------------

  Future<Response> _handlePair(Request request) async {
    final body = await _readJson(request);
    if (body['pairingSecret'] != pairingSecret) {
      return _json(403, {'error': 'bad pairing secret'});
    }
    final deviceName = (body['deviceName'] as String?)?.trim();
    if (deviceName == null || deviceName.isEmpty) {
      return _json(400, {'error': 'deviceName required'});
    }
    final token = uuidv7();
    await db.hubHostDao.issueToken(token, deviceName);
    return _json(200, PairResult(hubId: hubId, deviceToken: token).toJson());
  }

  Future<Response> _handlePostEvents(Request request) async {
    final body = await _readJson(request);
    final list = body['events'];
    if (list is! List) {
      return _json(400, {'error': 'events must be a list'});
    }
    final events = <Event>[
      for (final e in list) Event.fromJson((e as Map).cast<String, dynamic>()),
    ];
    await db.eventsDao.appendEvents(events);
    final maxSeq = await db.hubHostDao.assignSeqs();
    return _json(200, {'accepted': events.length, 'maxSeq': maxSeq});
  }

  Future<Response> _handleGetEvents(Request request) async {
    // Pick up anything authored locally on the host since the last request.
    await db.hubHostDao.assignSeqs();
    final after = int.tryParse(request.url.queryParameters['after'] ?? '0') ?? 0;
    final limit =
        int.tryParse(request.url.queryParameters['limit'] ?? '500') ?? 500;
    final page = await db.hubHostDao.eventsAfter(after, limit: limit);
    final maxSeq = await db.hubHostDao.maxSeq();
    return _json(
      200,
      EventPage(events: page.events, cursor: page.cursor, maxSeq: maxSeq)
          .toJson(),
    );
  }

  Future<Response> _handlePutBlob(Request request, String sha) async {
    if (!_isSha256(sha)) {
      return _json(400, {'error': 'blob name must be a sha256'});
    }
    final bytes = await request.read().expand((c) => c).toList();
    if (bytes.length > kMaxBlobBytes) {
      return _json(413, {'error': 'blob exceeds 20MB cap'});
    }
    final actual = sha256.convert(bytes).toString();
    if (actual != sha.toLowerCase()) {
      // A tampered or corrupt blob: bytes do not match the claimed hash.
      return _json(400, {'error': 'hash mismatch', 'expected': sha, 'actual': actual});
    }
    await blobs.save(bytes);
    return _json(200, {'sha256': actual});
  }

  Future<Response> _handleGetBlob(String sha, {required bool head}) async {
    if (!_isSha256(sha) || !await blobs.exists(sha)) {
      return Response.notFound(null);
    }
    if (head) {
      return Response.ok(null);
    }
    final bytes = await blobs.read(sha);
    return Response.ok(bytes,
        headers: {'content-type': 'application/octet-stream'});
  }

  // ---- helpers ------------------------------------------------------------

  Future<bool> _authorized(Request request) async {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) {
      return false;
    }
    final token = header.substring('Bearer '.length).trim();
    return db.hubHostDao.isValidToken(token);
  }

  bool _isPath(List<String> segments, List<String> want) =>
      segments.length == want.length &&
      List.generate(segments.length, (i) => segments[i] == want[i])
          .every((b) => b);

  Future<Map<String, dynamic>> _readJson(Request request) async {
    final text = await request.readAsString();
    if (text.isEmpty) return const {};
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const FormatException('expected a JSON object');
    }
    return decoded.cast<String, dynamic>();
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
        status,
        body: jsonEncode(body),
        headers: {'content-type': 'application/json'},
      );

  static final RegExp _sha256Re = RegExp(r'^[0-9a-f]{64}$');
  bool _isSha256(String s) => _sha256Re.hasMatch(s.toLowerCase());
}
