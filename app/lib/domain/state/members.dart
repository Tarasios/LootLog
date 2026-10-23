part of '../state.dart';

/// A display-only pet party member.
class PetState {
  const PetState({
    required this.petId,
    required this.name,
    this.customSpriteSha256,
  });

  final String petId;
  final String name;
  final String? customSpriteSha256;
}

/// A household member. Only `adult` members carry a ledger (income, vault,
/// personal categories); `dependent` and `pet` members enrich the party without
/// any money of their own.
class MemberState {
  const MemberState({
    required this.memberId,
    required this.name,
    required this.role,
    required this.active,
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

  /// For a pet: the adult whose budget funds this pet's categories, or null
  /// when the group funds them (the default). Meaningless for non-pets.
  final String? fundedByUserId;

  bool get isAdult => role == MemberRole.adult;
}
