/// The first-use tour content — a plain list of steps, kept pure and separate
/// from the overlay widget so it can be unit-tested (and so its wording stays
/// clean of banned flavor words in Classic mode).
///
/// The steps read their terms from the [Glossary], so Classic and Adventure
/// tell the same story in their own vocabulary from a single source.
library;

import 'package:flutter/material.dart';

import '../../ui/glossary.dart';

/// One page of the tour.
class TutorialStep {
  const TutorialStep({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

/// The six-step tour, worded for the active skin. Covers, in order: recording a
/// purchase, budget categories, the monthly wrap-up, savings goals, shared
/// savings & withdrawals, and syncing devices.
List<TutorialStep> tutorialSteps({required bool isAdventure}) {
  String t(GlossaryTerm term) => term.label(isAdventure: isAdventure);
  return [
    const TutorialStep(
      icon: Icons.add_circle_outline,
      title: 'Record a purchase',
      body: 'Logging a purchase is never more than two taps away. Tap the + '
          'button, type the amount, and pick what it was for. That’s it — the '
          'sooner you log, the more the numbers reflect real life.',
    ),
    TutorialStep(
      icon: Icons.pie_chart_outline,
      title: 'Budgets keep spending on track',
      body: 'Your money is split into ${t(Glossary.category)}s — one monthly '
          'limit each, personal or shared by the household. Every purchase '
          'draws down the budget you charge it to, so you always see what’s '
          'left.',
    ),
    TutorialStep(
      icon: Icons.event_available_outlined,
      title: t(Glossary.leftoverAllocated),
      body: 'At the end of each month you decide what happens to the money '
          'left in each budget: keep it there for next month, put it toward a '
          'savings goal, or move it to your personal spending. '
          '${Glossary.gracePeriod.helper}',
    ),
    TutorialStep(
      icon: Icons.flag_outlined,
      title: t(Glossary.quest),
      body: 'Set a target — a jacket, a canoe, a trip — and feed it with '
          'leftovers at month close. Watch the progress climb until you reach '
          'the goal.',
    ),
    TutorialStep(
      icon: Icons.account_balance_outlined,
      title: '${t(Glossary.warChest)} & withdrawals',
      body: '${Glossary.warChest.helper} Taking money back out is a '
          '${t(Glossary.withdrawal)}: another adult has to approve it first, so '
          'big decisions are always shared.',
    ),
    const TutorialStep(
      icon: Icons.sync,
      title: 'Sync stays on your devices',
      body: 'Everything works offline. When your devices are on the same '
          'network, one can host a hub and the others pair with it to stay in '
          'sync — no accounts, no servers, nothing leaves your home.',
    ),
  ];
}
