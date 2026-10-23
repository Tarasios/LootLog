part of '../event.dart';

/// Declares or amends a household member (last-writer-wins by [memberId]).
/// Only `adult` members carry income, a vault and personal categories;
/// `dependent` and `pet` members are display-level party members. Retiring a
/// member is `active: false`. [descriptionText] is the user-written character
/// description used by text-mode adventure.
class MemberSet extends Event {
  const MemberSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.memberId,
    required this.name,
    required this.role,
    this.active = true,
    this.customSpriteSha256,
    this.descriptionText,
    this.fundedByUserId,
  });

  final String memberId;
  final String name;
  final MemberRole role;
  final bool active;
  final String? customSpriteSha256;
  final String? descriptionText;

  /// For a pet: which adult funds this pet's budgets (null = the group,
  /// split by shares — the common case). Ignored for non-pet members.
  final String? fundedByUserId;

  @override
  String get type => 'MemberSet';

  @override
  Map<String, dynamic> payload() => {
    'memberId': memberId,
    'name': name,
    'role': role.name,
    'active': active,
    if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
    if (descriptionText != null) 'descriptionText': descriptionText,
    if (fundedByUserId != null) 'fundedByUserId': fundedByUserId,
  };
}

class PetSet extends Event {
  const PetSet({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.petId,
    required this.name,
    this.customSpriteSha256,
  });

  final String petId;
  final String name;
  final String? customSpriteSha256;

  @override
  String get type => 'PetSet';

  @override
  Map<String, dynamic> payload() => {
    'petId': petId,
    'name': name,
    if (customSpriteSha256 != null) 'customSpriteSha256': customSpriteSha256,
  };
}

/// Changes a household setting. Known keys: `spoilsGraceDays` (int, default 7),
/// `dissolutionTithePct` (int, default 10), `showNetWorth` (bool).
class SettingChanged extends Event {
  const SettingChanged({
    required super.eventId,
    required super.deviceId,
    required super.userId,
    required super.occurredAt,
    required super.createdAt,
    required this.key,
    required this.value,
  });

  final String key;
  final Object? value;

  @override
  String get type => 'SettingChanged';

  @override
  Map<String, dynamic> payload() => {'key': key, 'value': value};
}
