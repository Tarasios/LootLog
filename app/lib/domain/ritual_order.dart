/// The order the month-end ritual resolves a person's categories in: fun
/// first, then important, then necessities, ties broken by category id. The
/// reducer applies leftover allocations in this order (so default debt
/// payments spend fun money first), and any surface that previews several
/// allocations in a row must follow it to match. Pure Dart.
library;

import 'value_types.dart';

/// Where [priority] falls in the ritual: lower resolves first.
int ritualRank(SlicePriority priority) => switch (priority) {
      SlicePriority.fun => 0,
      SlicePriority.important => 1,
      SlicePriority.necessity => 2,
    };

/// Compares two categories by ritual order (a `List.sort` comparator body).
int compareRitualOrder(
  ({SlicePriority priority, String sliceId}) first,
  ({SlicePriority priority, String sliceId}) second,
) {
  final byPriority = ritualRank(first.priority).compareTo(ritualRank(second.priority));
  return byPriority != 0 ? byPriority : first.sliceId.compareTo(second.sliceId);
}
