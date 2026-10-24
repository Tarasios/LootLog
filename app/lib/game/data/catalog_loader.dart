/// Loads the decoration catalogue from `assets/game/catalog.json`.
library;

import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/decor/catalog.dart';

/// Reads the catalogue from [bundle] (the root bundle by default). A missing
/// or broken file yields [DecorCatalog.empty] rather than an error, so the
/// game still runs without decorations.
Future<DecorCatalog> loadDecorCatalog([AssetBundle? bundle]) async {
  try {
    final raw = await (bundle ?? rootBundle).loadString(
      'assets/game/catalog.json',
    );
    return DecorCatalog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } on Object {
    return DecorCatalog.empty;
  }
}
