/// Small derived providers that bridge device-local setup (the two profiles and
/// which one is "me") into the shape the feature view-models want: a `meUserId`
/// and a `userId -> display name` map. Kept out of the data layer because it is
/// purely a presentation convenience.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// The device owner's user id, or null before first-run setup completes.
final meUserIdProvider = Provider<String?>((ref) {
  return ref.watch(localSetupProvider).value?.meUserId;
});

/// Display names keyed by user id (empty before setup completes).
final userNamesProvider = Provider<Map<String, String>>((ref) {
  final setup = ref.watch(localSetupProvider).value;
  if (setup == null) return const {};
  return {
    for (final p in setup.profiles) p.userId: p.name,
  };
});
