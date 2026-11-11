/// The town book's later sections: the people and their food, the town's
/// history (tiers reached, festivals held) and the album (decorations owned,
/// and the way to the trophy hall). Every number comes from the rules' read
/// models.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/rewards/trophy_hall_screen.dart';
import '../../../ui/format.dart' show monthAbbreviation;
import '../../assets/pack_sprite.dart';
import '../../data/game_providers.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/town_book.dart';
import '../../domain/town/town_growth_lines.dart';
import '../hall_framed.dart';
import '../kit/kit.dart';
import 'town_loop_view.dart' show fillLine;

/// A figure with its label: the label in the body style, the number in the
/// numbers' style under [valueKey].
class BookStat extends StatelessWidget {
  const BookStat({super.key, required this.label, required this.value, required this.valueKey, this.suffix = ''});

  final String label;
  final String value;
  final String valueKey;
  final String suffix;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(child: Text(label, style: framedBodyStyle(context))),
        Text(value, key: ValueKey(valueKey), style: AdventureTokens.amount(context)),
        if (suffix.isNotEmpty) Text(suffix, style: framedMutedStyle(context)),
      ],
    ),
  );
}

/// The residents, what they eat a day, what is in store and how many days
/// of meals that is.
class PeopleSection extends StatelessWidget {
  const PeopleSection({super.key, required this.book, required this.lines});

  final TownBook book;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context) {
    final farmland = book.districts.where((listing) => listing.spec.id == 'farmland').firstOrNull;
    final days = book.dailyFoodNeed <= 0 ? 0 : book.foodStored ~/ book.dailyFoodNeed;
    return FramedSection(
      title: lines.line('book.section.people'),
      icon: Icons.groups,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BookStat(label: lines.line('book.stat.residents'), value: '${book.population}', valueKey: 'book-population'),
          BookStat(label: lines.line('book.stat.foodNeed'), value: '${book.dailyFoodNeed}', valueKey: 'book-food-need'),
          BookStat(
            label: lines.line('book.stat.foodStored'),
            value: '${book.foodStored}',
            valueKey: 'book-food-stored',
            suffix: ' / ${book.foodCapacity}',
          ),
          const SizedBox(height: 4),
          Text(
            fillLine(lines.line('book.people'), {
              'population': '${book.population}',
              'need': '${book.dailyFoodNeed}',
            }),
            style: framedBodyStyle(context),
          ),
          Text(fillLine(lines.line('book.daysCovered'), {'days': '$days'}), style: framedMutedStyle(context)),
          if (farmland != null && !farmland.owned)
            Text(lines.line('book.noFarmsYet'), style: framedMutedStyle(context)),
        ],
      ),
    );
  }
}

/// The tiers the town has reached, with their dates, and the festivals it
/// has held.
class HistorySection extends StatelessWidget {
  const HistorySection({super.key, required this.person, required this.lines});

  final PersonState person;
  final TownGrowthLines lines;

  static String _date(DateTime instant) {
    final day = GameDay.fromInstant(instant);
    return '${monthAbbreviation(day.month)} ${day.day}, ${day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final reached = person.tiersReached.entries.toList()
      ..sort((first, second) => first.key.index.compareTo(second.key.index));
    return FramedSection(
      title: lines.line('book.section.history'),
      icon: Icons.history_edu,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (reached.isEmpty) Text(lines.line('book.founded'), style: framedBodyStyle(context)),
          for (final entry in reached)
            Text(
              fillLine(lines.line('book.tierReachedOn'), {
                'tier': lines.line(tierNameKey(entry.key)),
                'date': _date(entry.value),
              }),
              style: framedBodyStyle(context),
            ),
          const SizedBox(height: 4),
          Text(
            fillLine(lines.line('book.festivals'), {'count': '${person.festivals.length}'}),
            key: const ValueKey('book-festivals'),
            style: framedBodyStyle(context),
          ),
        ],
      ),
    );
  }
}

/// The decorations this adult and the town own, and the way into the trophy
/// hall's list of trophies and titles.
class AlbumSection extends ConsumerWidget {
  const AlbumSection({super.key, required this.game, required this.personId, required this.lines});

  final GameState game;
  final String personId;
  final TownGrowthLines lines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(decorCatalogProvider).value ?? DecorCatalog.empty;
    final owned = <String, int>{...?game.decor.ownedByPerson[personId]};
    game.decor.townOwned.forEach((itemId, count) => owned[itemId] = (owned[itemId] ?? 0) + count);
    final items = [
      for (final itemId in owned.keys)
        if (catalog.itemFor(itemId) case final DecorItem item) item,
    ];
    final count = owned.values.fold(0, (sum, copies) => sum + copies);
    return FramedSection(
      title: lines.line('book.section.album'),
      icon: Icons.photo_album,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            count == 0 ? lines.line('book.noDecorations') : fillLine(lines.line('book.decorations'), {'count': '$count'}),
            key: const ValueKey('book-decorations'),
            style: framedBodyStyle(context),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: AdventureTokens.gap),
            Wrap(
              spacing: AdventureTokens.gap,
              runSpacing: AdventureTokens.gap,
              children: [
                for (final item in items.take(24))
                  Tooltip(message: item.name, child: PackSprite(assetKey: item.assetKey, label: item.name, scale: 2)),
              ],
            ),
          ],
          const SizedBox(height: AdventureTokens.gap),
          Align(
            alignment: Alignment.centerLeft,
            child: FramedButton(
              label: 'Trophy hall',
              secondary: true,
              onPressed: () => unawaited(TrophyHallScreen.open(context)),
            ),
          ),
        ],
      ),
    );
  }
}
