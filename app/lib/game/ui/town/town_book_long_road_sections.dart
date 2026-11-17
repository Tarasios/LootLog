/// The town book's long-road sections: homes, guards and the fields they
/// cover (a farm resting for want of guards is explained, never blamed),
/// goods in the workshops' lofts with a way into the workshop, and the
/// Castle's progress with a way to its sheet. Every number is the rules'
/// own (`longRoadBook`). ParchmentCards in the pixel tier, text panels in
/// the text tier.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/format.dart' show monthAbbreviation;
import '../../config/balance.dart';
import '../../domain/game_values.dart' show GameDay;
import '../../domain/town/long_road_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_framed.dart';
import '../kit/kit.dart';
import 'castle_sheet.dart';
import 'long_road_ui.dart';
import 'town_loop_view.dart' show fillLine;
import 'workshop_panel.dart';

/// A figure with its label, keyed for tests.
Widget _figure(BuildContext context, String label, String value, String key) => Row(
      children: [
        Expanded(child: Text(label, style: framedBodyStyle(context))),
        Text(value, key: ValueKey(key), style: AdventureTokens.amount(context)),
      ],
    );

/// Homes: residents housed.
class HomesSection extends StatelessWidget {
  const HomesSection({super.key, required this.book, required this.lines});

  final LongRoadBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) => FramedSection(
        title: lines.line('book.section.homes'),
        icon: Icons.cottage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _figure(context, lines.line('book.stat.homes'), '${book.housing}', 'book-housing'),
            Text(fillLine(lines.line('book.homes'), {'count': '${book.housing}'}), style: framedMutedStyle(context)),
          ],
        ),
      );
}

/// Guards and the farm fields they cover; resting farms and what to build.
class GuardsSection extends StatelessWidget {
  const GuardsSection({super.key, required this.book, required this.lines});

  final LongRoadBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) {
    final watched = book.guardedFields - Balance.unguardedFarmPlots;
    return FramedSection(
      title: lines.line('book.section.guards'),
      icon: Icons.shield,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _figure(context, lines.line('book.stat.guards'), '${book.guards}', 'book-guards'),
          _figure(context, lines.line('book.stat.fields'), '${book.fieldsOpen}', 'book-fields'),
          const SizedBox(height: AdventureTokens.gap),
          Text(fillLine(lines.line('guards.capacity'), {'guards': '${book.guards}', 'plots': '$watched'}),
              style: framedBodyStyle(context)),
          if (book.restingFarms > 0) ...[
            Text(fillLine(lines.line('book.restingFarms'), {'count': '${book.restingFarms}'}),
                key: const ValueKey('book-resting'), style: framedBodyStyle(context)),
            Text(lines.line('guards.whatToBuild'), style: framedMutedStyle(context)),
          ] else
            Text(lines.line('book.allGuarded'), style: framedMutedStyle(context)),
        ],
      ),
    );
  }
}

/// Goods in the lofts and the workshops' jobs.
class GoodsSection extends StatelessWidget {
  const GoodsSection({super.key, required this.book, required this.lines});

  final LongRoadBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) => FramedSection(
        title: lines.line('goods.title'),
        icon: Icons.inventory,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              book.goods.isEmpty
                  ? lines.line('goods.none')
                  : fillLine(lines.line('goods.stored'), {'goods': goodsText(book.goods, lines)}),
              key: const ValueKey('book-goods'),
              style: framedBodyStyle(context),
            ),
            if (book.workshops > 0) ...[
              Text(fillLine(lines.line('book.jobs'), {'working': '${book.jobsWorking}', 'done': '${book.jobsDone}'}),
                  style: framedMutedStyle(context)),
              const SizedBox(height: AdventureTokens.gap),
              sheetButton(lines.line('refine.title'), () => unawaited(showWorkshopSheet(context)),
                  key: const ValueKey('book-open-workshop')),
            ],
          ],
        ),
      );
}

/// The Castle: the promise before the city, then its stages.
class CastleSection extends StatelessWidget {
  const CastleSection({super.key, required this.book, required this.lines});

  final LongRoadBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) {
    final stages = Balance.castleStages.length;
    return FramedSection(
      title: lines.line('castle.title'),
      icon: Icons.fort,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!book.castleOpen)
            Text(lines.line('castle.teaser'), style: framedBodyStyle(context))
          else ...[
            Text(fillLine(lines.line('castle.progress'), {'count': '${book.castleStagesDone}'}),
                key: const ValueKey('book-castle-stages'), style: framedBodyStyle(context)),
            const SizedBox(height: AdventureTokens.gap),
            FramedMeter(book.castleStagesDone / stages, color: AdventureTokens.gold, semanticsLabel: 'Castle'),
            const SizedBox(height: AdventureTokens.gap),
            if (book.castleComplete)
              Text(lines.line('castle.complete'), style: framedMutedStyle(context))
            else if (book.castleBuilding && book.castleStageEndsAt != null)
              Text(
                fillLine(lines.line('castle.building'), {
                  'stage': lines.line(castleStageNameKey(Balance.castleStages[book.castleNextStage - 1].key)),
                  'time': 'on ${_date(book.castleStageEndsAt!)}',
                }),
                style: framedMutedStyle(context),
              )
            else
              Text(fillLine(lines.line('castle.next'),
                  {'stage': lines.line(castleStageNameKey(Balance.castleStages[book.castleNextStage - 1].key))}),
                  style: framedMutedStyle(context)),
            const SizedBox(height: AdventureTokens.gap),
            sheetButton(lines.line('castle.title'), () => unawaited(showCastleSheet(context)),
                key: const ValueKey('book-open-castle')),
          ],
        ],
      ),
    );
  }

  /// "Mar 4", in the household's days.
  static String _date(DateTime instant) {
    final day = GameDay.fromInstant(instant);
    return '${monthAbbreviation(day.month)} ${day.day}';
  }
}
