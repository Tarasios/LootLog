/// The activity feed as a provider-backed screen: used for the phone's Activity
/// tab and the desktop shell's right-hand pane.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../household_context.dart';
import 'activity_model.dart';
import 'activity_view.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final meUserId = ref.watch(meUserIdProvider);
    final names = ref.watch(userNamesProvider);

    if (state == null || meUserId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final items = buildActivityFeed(
      state,
      events,
      userNames: names,
      meUserId: meUserId,
    );
    return ActivityFeedView(items: items);
  }
}
