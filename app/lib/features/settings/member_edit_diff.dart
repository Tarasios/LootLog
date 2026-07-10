/// Pure change detection for the member editor: saving with nothing changed
/// must append no event at all (the log is permanent — no-op MemberSets are
/// noise in the household's audit trail).
library;

import '../../domain/state.dart';
import '../../domain/value_types.dart';

/// Whether the edited values differ from [existing]. Null and empty
/// descriptions are equivalent (the sheet renders null as an empty field).
bool memberEditChanged(
  MemberState existing, {
  required String name,
  required MemberRole role,
  required bool active,
  String? customSpriteSha256,
  String? descriptionText,
}) {
  String norm(String? s) => (s ?? '').trim();
  return existing.name != name ||
      existing.role != role ||
      existing.active != active ||
      existing.customSpriteSha256 != customSpriteSha256 ||
      norm(existing.descriptionText) != norm(descriptionText);
}
