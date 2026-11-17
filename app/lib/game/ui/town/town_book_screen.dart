/// The town book: a full screen of the town's growth, under the compact
/// wood header. Prosperity with a meter to the next tier and what counts
/// toward it; what the next tier needs (prosperity and, from the village,
/// food, and homes for the town and the city), each ticked off or phrased
/// as what to do next; the people and their food; homes, guards and the
/// fields they cover, goods and the Castle (`town_book_long_road_sections`);
/// the town's history; and the album of decorations and trophies. Every number is the rules' own (`townBook`). Reached from the
/// town Menu and by tapping the date chip; the text tier shows the same
/// sections as text panels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/game_providers.dart';
import '../../domain/town/long_road_book.dart';
import '../../domain/town/town_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_common.dart';
import '../hall_framed.dart';
import '../hall_ledger_view.dart';
import '../kit/kit.dart';
import 'town_book_long_road_sections.dart';
import 'town_book_sections.dart';
import 'town_growth_providers.dart';
import 'town_loop_view.dart' show fillLine;

class TownBookScreen extends ConsumerWidget {
  const TownBookScreen({super.key});

  static Future<void> open(BuildContext context) => pushHallScreen(context, const TownBookScreen());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = hallGameState(ref);
    final meId = ref.watch(hallLedgerViewProvider).meId ?? '';
    final clock = ref.watch(gameClockProvider);
    final lines = ref.watch(townGrowthLinesProvider).value ?? TownGrowthLines.defaults;
    return HallTicker(builder: (context) {
      final now = clock.now();
      final book = townBook(game, meId, now);
      final longRoad = longRoadBook(game, meId, now);
      return FramedHallScreen(
        title: lines.line('book.title'),
        children: [
          ProsperitySection(book: book, lines: lines),
          NextTierSection(book: book, lines: lines, homes: longRoad),
          PeopleSection(book: book, lines: lines),
          HomesSection(book: longRoad, lines: lines),
          GuardsSection(book: longRoad, lines: lines),
          GoodsSection(book: longRoad, lines: lines),
          CastleSection(book: longRoad, lines: lines),
          HistorySection(person: game.person(meId), lines: lines),
          AlbumSection(game: game, personId: meId, lines: lines),
        ],
      );
    });
  }
}

/// Prosperity now, a meter toward the next tier (by the peak, which is what
/// tiers read) and what counts toward it.
class ProsperitySection extends StatelessWidget {
  const ProsperitySection({super.key, required this.book, required this.lines});

  final TownBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) {
    final needed = book.nextTierProsperity;
    final next = book.nextTier;
    return FramedSection(
      title: lines.line('book.section.prosperity'),
      icon: Icons.auto_graph,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${book.prosperity}', key: const ValueKey('book-prosperity'), style: AdventureTokens.amount(context)),
              if (needed != null) ...[
                Text(' / ', style: AdventureTokens.amount(context)),
                Text('$needed', key: const ValueKey('book-next-prosperity'), style: AdventureTokens.amount(context)),
              ],
              const Spacer(),
              Text(lines.line(tierNameKey(book.tier)), style: AdventureTokens.label(context)),
            ],
          ),
          const SizedBox(height: AdventureTokens.gap),
          FramedMeter(
            needed == null ? 1 : (book.peakProsperity / needed).clamp(0.0, 1.0),
            color: AdventureTokens.gold,
            semanticsLabel: 'Prosperity ${book.prosperity}',
          ),
          const SizedBox(height: AdventureTokens.gap),
          Text(
            next == null || needed == null
                ? fillLine(lines.line('book.top'), {'prosperity': '${book.prosperity}'})
                : fillLine(lines.line('book.prosperity'), {
                    'prosperity': '${book.prosperity}',
                    'tier': lines.line(tierNameKey(next)),
                    'needed': '$needed',
                  }),
            style: framedBodyStyle(context),
          ),
          Text(lines.line('book.counts'), style: framedMutedStyle(context)),
        ],
      ),
    );
  }
}

/// What growing into the next tier needs, each need ticked off or phrased
/// as the next thing to do. A town short of food only waits.
class NextTierSection extends StatelessWidget {
  const NextTierSection({super.key, required this.book, required this.lines, this.homes});

  final TownBook book;
  final TownGrowthLines lines;

  /// The homes the next tier needs (the town and the city need some).
  final LongRoadBook? homes;

  @override
  Widget build(BuildContext context) {
    final next = book.nextTier;
    final needed = book.nextTierProsperity;
    if (next == null || needed == null) {
      return FramedSection(
        title: lines.line('book.section.next'),
        icon: Icons.flag,
        child: Text(fillLine(lines.line('book.top'), {'prosperity': '${book.prosperity}'}),
            style: framedBodyStyle(context)),
      );
    }
    final prosperityMet = book.peakProsperity >= needed;
    final food = book.foodSecureTarget;
    return FramedSection(
      title: fillLine(lines.line('book.nextTier'), {'tier': lines.line(tierNameKey(next))}),
      icon: Icons.flag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeedLine(
            met: prosperityMet,
            text: fillLine(lines.line(prosperityMet ? 'book.prosperityDone' : 'book.prosperityToGo'), {
              'needed': '$needed',
              'missing': '${needed - book.peakProsperity}',
            }),
          ),
          if (book.nextTierNeedsFood)
            NeedLine(
              met: book.foodSecure,
              text: fillLine(lines.line(_foodLineKey(book)), {
                'tier': lines.line(tierNameKey(next)),
                'stored': '${book.foodStored}',
                'food': '$food',
                'missing': '${food - book.foodStored}',
              }),
            ),
          if (homes case final homes? when homes.nextTierNeedsHomes)
            NeedLine(
              met: homes.housed,
              text: fillLine(lines.line(homes.housed ? 'book.housingDone' : 'book.housingToGo'), {
                'tier': lines.line(tierNameKey(next)),
                'housing': '${homes.housing}',
                'needed': '${homes.housingNeeded}',
              }),
            ),
          if (homes case final homes? when homes.nextTierNeedsHomes && !homes.housed && prosperityMet) ...[
            const SizedBox(height: AdventureTokens.gap),
            Text(lines.line('book.waitingOnHomes'), style: framedMutedStyle(context)),
          ],
          if (book.waitingOnFood) ...[
            const SizedBox(height: AdventureTokens.gap),
            Text(lines.line('book.waitingOnHarvest'), style: framedMutedStyle(context)),
          ],
        ],
      ),
    );
  }
}

/// The food need's line: ready, or what to do next (harvest, and build or
/// raise the granary when the stores could not hold it).
String _foodLineKey(TownBook book) {
  if (book.foodSecure) return 'book.foodDone';
  if (!book.needsMoreStorage) return 'book.foodToGo';
  return book.hasGranary ? 'book.foodToGoBiggerGranary' : 'book.foodToGoGranary';
}

/// One need of the next tier: a tick when met, an arrow toward the next
/// step when not.
class NeedLine extends StatelessWidget {
  const NeedLine({super.key, required this.met, required this.text});

  final bool met;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.arrow_circle_right,
          size: 18,
          color: met ? AdventureTokens.gainInk : AdventureTokens.inkMuted,
        ),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: framedBodyStyle(context))),
      ],
    ),
  );
}

