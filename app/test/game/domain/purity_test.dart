/// `lib/game/domain/` is pure Dart: no file under it imports Flutter or
/// `dart:ui`, directly or through anything it imports from the rest of `lib/`
/// (relative or `package:lootlog/` imports, exports and parts are followed).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _directive = RegExp(
  r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

/// Whether [uri] pulls in Flutter or the engine's UI library.
bool _isImpure(String uri) => uri.startsWith('package:flutter/') || uri == 'dart:ui';

/// The file [uri] names, seen from [from]; null for SDK and other packages.
File? _resolve(String uri, File from) {
  if (uri.startsWith('package:lootlog/')) {
    return File('lib/${uri.substring('package:lootlog/'.length)}');
  }
  if (uri.contains(':')) return null;
  return File.fromUri(from.absolute.parent.uri.resolve(uri));
}

/// The chains of files from [root] that reach an impure import, each ending
/// with that import.
List<String> _impureChains(File root) {
  final failures = <String>[];
  final visited = <String>{};
  void visit(File file, List<String> chain) {
    final path = file.absolute.path;
    if (!visited.add(path)) return;
    for (final match in _directive.allMatches(file.readAsStringSync())) {
      final uri = match.group(1)!;
      if (_isImpure(uri)) {
        failures.add([...chain, uri].join(' -> '));
        continue;
      }
      final target = _resolve(uri, file);
      if (target != null && target.existsSync()) {
        visit(target, [...chain, target.path.replaceAll(r'\', '/')]);
      }
    }
  }

  visit(root, [root.path.replaceAll(r'\', '/')]);
  return failures;
}

void main() {
  test('lib/game/domain imports neither Flutter nor dart:ui, even indirectly', () {
    final domainFiles = Directory('lib/game/domain')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    expect(domainFiles, isNotEmpty);

    final failures = [for (final file in domainFiles) ..._impureChains(file)];
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('the guard catches a direct Flutter import', () {
    final scratch = Directory.systemTemp.createTempSync('lootlog_purity');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final impure = File('${scratch.path}/impure.dart')
      ..writeAsStringSync("import 'package:flutter/widgets.dart';\n");
    final indirect = File('${scratch.path}/indirect.dart')
      ..writeAsStringSync("import 'impure.dart';\n");

    expect(_impureChains(impure), hasLength(1));
    expect(_impureChains(indirect).single, endsWith('package:flutter/widgets.dart'));
  });
}
