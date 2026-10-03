/// The party roster as pickers and labels want it: who the adults are, who the
/// pets are, and what everyone is called.
///
/// Everything derives from [MemberSet] state, so households of any size work
/// and renames show everywhere. The legacy two-profile [LocalSetup] is only a
/// fallback for histories that predate member events.
library;

import '../data/setup/local_setup.dart';
import '../domain/state.dart';
import '../domain/value_types.dart';

/// One selectable party member: an id and its display name.
class RosterEntry {
  const RosterEntry({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is RosterEntry && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'RosterEntry($id, $name)';
}

int _byName(RosterEntry a, RosterEntry b) {
  final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// Every active adult, this device's adult ([meUserId]) first, the rest by
/// name. A single-adult household yields exactly one entry. Histories with no
/// adult [MemberSet] fall back to the legacy [setup] profiles (de-duplicated).
List<RosterEntry> partyAdults(
  HouseholdState state, {
  String? meUserId,
  LocalSetup? setup,
}) {
  var adults = [
    for (final m in state.members.values)
      if (m.isAdult && m.active) RosterEntry(id: m.memberId, name: m.name),
  ];
  if (adults.isEmpty && setup != null) {
    final seen = <String>{};
    adults = [
      for (final p in setup.profiles)
        if (seen.add(p.userId)) RosterEntry(id: p.userId, name: p.name),
    ];
  }
  adults.sort((a, b) {
    if (a.id == meUserId) return -1;
    if (b.id == meUserId) return 1;
    return _byName(a, b);
  });
  return adults;
}

/// Every active pet member, by name.
List<RosterEntry> partyPets(HouseholdState state) => [
      for (final m in state.members.values)
        if (m.role == MemberRole.pet && m.active)
          RosterEntry(id: m.memberId, name: m.name),
    ]..sort(_byName);

/// Display names keyed by member id for every member (adults, dependents and
/// pets, retired ones included so old records still read well). Ids the roster
/// doesn't know resolve through the legacy [setup] profiles.
Map<String, String> memberNames(HouseholdState state, {LocalSetup? setup}) => {
      if (setup != null)
        for (final p in setup.profiles) p.userId: p.name,
      for (final m in state.members.values) m.memberId: m.name,
    };
