/// The dependents and pets who stroll the town, read off the household roster.
/// Adults live in the houses; dependents and pets are display-level party
/// members, so they only ever appear as villagers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers.dart';
import '../../../domain/value_types.dart';
import '../../../features/household_context.dart';
import '../../scenes/town/town_game.dart';

/// Active dependents, then active pets, by name. Empty until the household
/// state loads.
final townsfolkProvider = Provider<List<TownsfolkEntry>>((ref) {
  final state = ref.watch(householdStateProvider).value;
  if (state == null) return const [];
  final dependents = [
    for (final member in state.members.values)
      if (member.role == MemberRole.dependent && member.active) member.name,
  ]..sort((first, second) => first.toLowerCase().compareTo(second.toLowerCase()));
  return [
    for (final name in dependents) (name: name, isPet: false),
    for (final pet in ref.watch(partyPetsProvider)) (name: pet.name, isPet: true),
  ];
});
