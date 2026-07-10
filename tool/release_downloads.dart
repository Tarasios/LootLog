#!/usr/bin/env dart
// LootLog "resume number" — cumulative release download counts.
//
// LootLog ships **no telemetry**. The app never phones home, has no analytics
// SDK, and opens no network connection you didn't ask for (sync is LAN-only;
// Google Sheets is opt-in and isolated). So the only honest way to answer "how
// many people use it?" is to count how many times the release binaries were
// downloaded from GitHub — a number GitHub keeps for us, on the public Releases
// API, with no cooperation from the running app.
//
// This script fetches every release of a repository, sums `download_count`
// across every attached asset, and prints per-asset, per-release, and grand
// totals — the "resume number".
//
// Usage:
//   dart run tool/release_downloads.dart [owner/repo]
//
//   owner/repo   Defaults to tarasios/duobudget.
//
// Environment:
//   GITHUB_TOKEN  Optional. A classic/fine-grained token (no scopes needed for
//                 public repos) raises the API rate limit from 60 to 5000
//                 requests/hour and is required for private repos. Never commit
//                 a token; pass it in the environment only.
//
// Notes:
//   * download_count is cumulative and provided by GitHub — it counts asset
//     downloads, not installs or launches, and there is deliberately no way to
//     get the latter without telemetry we refuse to add.
//   * The source tarball/zip GitHub auto-generates for every release is NOT an
//     asset and has no public download count; only uploaded binaries are
//     counted here, which is exactly what we ship.
//
// This is a standalone script: it imports only the Dart SDK, so it runs with a
// bare `dart` (no `flutter pub get`, no package resolution).

import 'dart:convert';
import 'dart:io';

const _defaultRepo = 'tarasios/duobudget';

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(
      'Usage: dart run tool/release_downloads.dart [owner/repo]\n'
      'Prints cumulative GitHub Release download counts (the resume number).\n'
      'Set GITHUB_TOKEN to raise the API rate limit or reach a private repo.',
    );
    return;
  }

  final repo = args.isNotEmpty ? args.first : _defaultRepo;
  if (!RegExp(r'^[^/]+/[^/]+$').hasMatch(repo)) {
    stderr.writeln('Expected an "owner/repo" argument, got: $repo');
    exitCode = 2;
    return;
  }

  final List<dynamic> releases;
  try {
    releases = await _fetchAllReleases(repo);
  } on _ApiException catch (e) {
    stderr.writeln('GitHub API error: ${e.message}');
    exitCode = 1;
    return;
  }

  if (releases.isEmpty) {
    stdout.writeln('No releases found for $repo yet.');
    return;
  }

  var grandTotal = 0;
  final perAssetName = <String, int>{};

  stdout.writeln('LootLog download counts — $repo');
  stdout.writeln('=' * 56);

  // Releases come back newest-first; show them that way.
  for (final release in releases.cast<Map<String, dynamic>>()) {
    final tag = (release['tag_name'] ?? '(untagged)') as String;
    final assets = (release['assets'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (assets.isEmpty) continue;

    var releaseTotal = 0;
    stdout.writeln('\n$tag');
    for (final asset in assets) {
      final name = asset['name'] as String;
      final count = (asset['download_count'] as num?)?.toInt() ?? 0;
      releaseTotal += count;
      perAssetName[name] = (perAssetName[name] ?? 0) + count;
      stdout.writeln('  ${count.toString().padLeft(8)}  $name');
    }
    stdout.writeln('  ${'-' * 8}');
    stdout.writeln('  ${releaseTotal.toString().padLeft(8)}  (release total)');
    grandTotal += releaseTotal;
  }

  stdout.writeln('\n${'=' * 56}');
  stdout.writeln('By platform (summed across all releases):');
  final byPlatform = <String, int>{};
  perAssetName.forEach((name, count) {
    byPlatform[_platformOf(name)] =
        (byPlatform[_platformOf(name)] ?? 0) + count;
  });
  final platforms = byPlatform.keys.toList()..sort();
  for (final p in platforms) {
    stdout.writeln('  ${byPlatform[p]!.toString().padLeft(8)}  $p');
  }

  stdout.writeln('=' * 56);
  stdout.writeln(
      '  ${grandTotal.toString().padLeft(8)}  TOTAL DOWNLOADS (resume number)');
}

/// Buckets an asset filename into a coarse platform label for the summary.
String _platformOf(String assetName) {
  final n = assetName.toLowerCase();
  if (n.endsWith('.apk')) return 'Android (APK)';
  if (n.contains('windows') || n.endsWith('.exe')) return 'Windows';
  if (n.endsWith('.dmg') || n.contains('macos') || n.endsWith('.app.zip')) {
    return 'macOS';
  }
  if (n.contains('linux') ||
      n.endsWith('.appimage') ||
      n.endsWith('.tar.gz')) {
    return 'Linux';
  }
  return 'Other';
}

/// Fetches every release, following pagination until a short page is returned.
Future<List<dynamic>> _fetchAllReleases(String repo) async {
  final token = Platform.environment['GITHUB_TOKEN'];
  final client = HttpClient();
  final all = <dynamic>[];
  try {
    for (var page = 1;; page++) {
      final uri = Uri.https('api.github.com', '/repos/$repo/releases',
          {'per_page': '100', 'page': '$page'});
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        ..set(HttpHeaders.userAgentHeader, 'duobudget-release-downloads')
        ..set('X-GitHub-Api-Version', '2022-11-28');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 404) {
        throw _ApiException(
            'repository "$repo" not found (or private and no GITHUB_TOKEN set)');
      }
      if (response.statusCode == 403 &&
          response.headers.value('x-ratelimit-remaining') == '0') {
        throw _ApiException(
            'rate limit exceeded — set GITHUB_TOKEN to raise it to 5000/hour');
      }
      if (response.statusCode != 200) {
        throw _ApiException('HTTP ${response.statusCode}: $body');
      }
      final page0 = jsonDecode(body) as List<dynamic>;
      all.addAll(page0);
      if (page0.length < 100) break; // last page
    }
  } finally {
    client.close();
  }
  return all;
}

class _ApiException implements Exception {
  _ApiException(this.message);
  final String message;
}
