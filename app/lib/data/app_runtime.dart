/// Runtime construction of the file-backed data layer.
///
/// Kept separate from `providers.dart` so the providers (and their tests) stay
/// free of `path_provider` / `dart:io` startup concerns. `main` calls
/// [buildDataLayerOverrides] and passes the result to `ProviderScope`.
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'blobs/blob_store.dart';
import 'db/database.dart';
import 'providers.dart';

/// Opens the app database file at `<documents>/lootlog.sqlite`.
AppDatabase openAppDatabase(Directory documentsDir) {
  final file = File(p.join(documentsDir.path, 'lootlog.sqlite'));
  return AppDatabase(NativeDatabase.createInBackground(file));
}

/// The blob store rooted at `<documents>/blobs`.
BlobStore openBlobStore(Directory documentsDir) =>
    BlobStore(Directory(p.join(documentsDir.path, 'blobs')));

/// Builds the provider overrides that back the app with on-disk storage.
Future<List<Override>> buildDataLayerOverrides() async {
  final documentsDir = await getApplicationDocumentsDirectory();
  return [
    appDatabaseProvider.overrideWithValue(openAppDatabase(documentsDir)),
    blobStoreProvider.overrideWithValue(openBlobStore(documentsDir)),
  ];
}
