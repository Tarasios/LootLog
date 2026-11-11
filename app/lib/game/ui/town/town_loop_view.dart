/// What the town loop shows this device's adult right now — the day's
/// visitor, the week's town spirit, the weekend festival and what the crews
/// made while they were away — read from the game state on every build, plus
/// the wording helpers that fill `town_events.json`'s placeholders. Display
/// only: every change goes through the game commands.
library;

import '../../assets/asset_key.dart';
import '../../assets/asset_registry.dart';
import '../../domain/game_state.dart';
import '../../domain/game_values.dart';
import '../../domain/town/away_summary.dart';
import '../../domain/town/daily_event.dart';
import '../../domain/town/festival.dart';
import '../../domain/town/town_event_lines.dart';
import '../hall_names.dart';

class TownLoopView {
  const TownLoopView({
    required this.today,
    required this.dayOpened,
    required this.offer,
    required this.spiritDays,
    required this.festival,
    required this.festivalRewards,
    required this.away,
    required this.offerBuilding,
  });

  /// The loop for [meId] as of [now].
  factory TownLoopView.from(GameState game, String meId, DateTime now) {
    final today = GameDay.fromInstant(now);
    final me = game.person(meId);
    final monday = today.weekStart;
    final offer = game.offerFor(meId, today);
    final plotIndex = offer?.plotIndex;
    final offerBuilding = plotIndex == null ? null : game.hall.plots[plotIndex]?.building?.type;
    final festival = festivalToday(me, today);
    return TownLoopView(
      today: today,
      dayOpened: me.streak.loggedDays.contains(today),
      offer: offer,
      spiritDays: [
        for (var offset = 0; offset < 5; offset++) me.streak.loggedDays.contains(monday.addDays(offset)),
      ],
      festival: festival,
      festivalRewards: festival == null
          ? const []
          : [
              for (final rewardId in [
                legacyFestivalRewardId(meId, monday),
                ...festivalRewardIds(meId, monday),
                jointFestivalRewardId(meId, monday),
              ])
                ?me.unclaimedRewards[rewardId],
            ],
      away: awaySummary(game, now),
      offerBuilding: offerBuilding,
    );
  }

  final GameDay today;

  /// Whether this adult has logged (or checked in) today, which opens the
  /// town's day and brings its visitor.
  final bool dayOpened;

  /// Today's visitor, while it waits.
  final DailyOffer? offer;

  /// Monday to Friday of this week: logged or not.
  final List<bool> spiritDays;

  /// The festival held today (weekends only, once granted).
  final FestivalTier? festival;

  /// The festival's gifts still waiting in the inbox: one per tier
  /// reached (and a pre-tier one), plus the joint bonus.
  final List<PendingReward> festivalRewards;

  final AwaySummary away;

  /// A windfall's producer.
  final BuildingType? offerBuilding;

  int get weekdaysLogged => spiritDays.where((logged) => logged).length;
  bool get weekend => isFestivalWeekend(today);

  /// The festival this week's spirit earns so far.
  FestivalTier get earnedFestival => festival ?? festivalTierFor(weekdaysLogged);
}

/// The asset key a [kind] of visitor is drawn with: its own art
/// (`town.visitor.<kind>.idle`) when [registry] has some, otherwise the
/// supply wagon for a trader or a villager for the others (and with no art
/// for those either, the sprite's text card).
AssetKey visitorAssetKey(DailyEventKind kind, AssetRegistry registry) {
  final own = AssetKey('town', 'visitor', kind.name);
  if (registry.hasArt(own)) return own;
  return switch (kind) {
    DailyEventKind.trader => const AssetKey('town', 'wagon'),
    DailyEventKind.windfall => const AssetKey('npc', 'villager', 'b'),
    DailyEventKind.visitor => const AssetKey('npc', 'villager', 'a'),
  };
}

/// The visitor's name on a text card.
String visitorLabel(DailyEventKind kind) => switch (kind) {
  DailyEventKind.trader => 'Trader',
  DailyEventKind.windfall => 'Foreman',
  DailyEventKind.visitor => 'Visitor',
};

/// Fills `{placeholders}` in [template].
String fillLine(String template, Map<String, String> values) {
  var text = template;
  values.forEach((placeholder, value) => text = text.replaceAll('{$placeholder}', value));
  return text;
}

/// "Fair" from "fair": a line used as a title.
String capitalised(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// The town loop's wording, filled.
extension TownLoopLines on TownEventLines {
  /// How the crews worked: full days, or short shifts on the quiet days.
  String shiftNote({required int quietDays, required bool todayLogged}) {
    if (quietDays == 0) return line('away.fullDays');
    final phrase = quietDays == 1 ? '1 quiet day' : '$quietDays quiet days';
    return fillLine(line(todayLogged ? 'away.shortShiftsLogged' : 'away.shortShifts'), {'quietDays': phrase});
  }

  String festivalName(FestivalTier tier) => line(festivalNameKey(tier));

  /// The tag over today's visitor.
  String visitorTag(DailyOffer offer, BuildingType? building) => fillLine(line('tag.${offer.kind.name}'), {
    'building': building == null ? 'yard' : HallNames.building(building),
  });

  /// The visitor's story, with what changes hands.
  String offerStory(DailyOffer offer, BuildingType? building) => fillLine(line(offer.flavourKey), {
    'gives': HallNames.bundle(offer.gives),
    'receives': HallNames.loot(offer.receives),
    'building': building == null ? 'yard' : HallNames.building(building),
  });

  /// "3 of 5 weekdays logged this week." plus what the weekend holds.
  List<String> spiritLines(TownLoopView view) {
    final earned = view.earnedFestival;
    final logged = fillLine(line('spirit.logged'), {'logged': '${view.weekdaysLogged}'});
    if (view.weekend) {
      return [logged, fillLine(line('spirit.weekend'), {'festival': festivalName(earned)})];
    }
    final lines = [logged, fillLine(line('spirit.weekday'), {'festival': festivalName(earned)})];
    final next = _nextFestival(view.weekdaysLogged);
    if (next != null) {
      final more = next.weekdays - view.weekdaysLogged;
      // Weekdays from today to Friday not logged yet: only a reachable
      // festival is suggested.
      final daysLeft = [
        for (var offset = view.today.weekday - 1; offset < 5; offset++)
          if (!view.spiritDays[offset]) offset,
      ].length;
      if (more <= daysLeft) {
        lines.add(
          fillLine(line('spirit.next'), {
            'more': more == 1 ? '1 more weekday' : '$more more weekdays',
            'festival': festivalName(next.tier),
          }),
        );
      }
    }
    return lines;
  }

  static ({FestivalTier tier, int weekdays})? _nextFestival(int logged) {
    for (var weekdays = logged + 1; weekdays <= 5; weekdays++) {
      final tier = festivalTierFor(weekdays);
      if (tier != festivalTierFor(logged)) return (tier: tier, weekdays: weekdays);
    }
    return null;
  }
}
