/// Small derived providers that give feature view-models the household's shape:
/// this device's `meUserId`, a `memberId -> display name` map, and the active
/// adults and pets for owner pickers. Names and rosters derive from [MemberSet]
/// state (any household size, renames included); the device-local setup only
/// says which adult this device is. Kept out of the data layer because it is
/// purely a presentation convenience.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'household_roster.dart';

/// The device owner's user id, or null before first-run setup completes.
final meUserIdProvider = Provider<String?>((ref) {
  return ref.watch(localSetupProvider).value?.meUserId;
});

/// Display names keyed by member id (empty before setup completes).
final userNamesProvider = Provider<Map<String, String>>((ref) {
  final setup = ref.watch(localSetupProvider).value;
  final state = ref.watch(householdStateProvider).value;
  if (setup == null) return const {};
  if (state == null) {
    return {for (final p in setup.profiles) p.userId: p.name};
  }
  return memberNames(state, setup: setup);
});

/// Every active adult, this device's adult first (empty until state loads).
final partyAdultsProvider = Provider<List<RosterEntry>>((ref) {
  final setup = ref.watch(localSetupProvider).value;
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return const [];
  return partyAdults(state, meUserId: setup?.meUserId, setup: setup);
});

/// Every active pet member, by name.
final partyPetsProvider = Provider<List<RosterEntry>>((ref) {
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return const [];
  return partyPets(state);
});
