/// Shared classification of a [MemberSet] against the previous one for the
/// same member — the single source of truth for how the activity feed and the
/// change log describe a member edit.
library;

import '../../domain/event.dart';

/// What a [MemberSet] event did to its member, relative to the previous
/// [MemberSet] for the same `memberId` (null = first sighting).
enum MemberSetChange {
  /// First sighting of an active member — they joined the party.
  added,

  /// `active: false` — the member was retired (history kept).
  retired,

  /// Only the custom sprite changed — a portrait swap, worth its own wording.
  portraitOnly,

  /// Any other edit (name, role, description, reactivation, …).
  updated,
}

/// Classifies [e] against [prev], the last `MemberSet` seen for the same
/// member. Callers keep their own `memberId -> MemberSet` map and their own
/// wording; only the decision logic is shared.
MemberSetChange classifyMemberSet(MemberSet e, MemberSet? prev) {
  if (!e.active) return MemberSetChange.retired;
  if (prev == null) return MemberSetChange.added;
  final onlyPortraitChanged = prev.customSpriteSha256 != e.customSpriteSha256 &&
      prev.name == e.name &&
      prev.role == e.role &&
      prev.active == e.active &&
      prev.descriptionText == e.descriptionText;
  return onlyPortraitChanged
      ? MemberSetChange.portraitOnly
      : MemberSetChange.updated;
}
