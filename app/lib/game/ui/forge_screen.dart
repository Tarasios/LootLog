/// The Forge & hero screen: the hero's look (free cosmetic fields), their
/// power, and the gear slots — current piece, the gear types each slot takes,
/// the next tier's cost, and why an upgrade can't happen yet. Anyone may pay
/// for anyone's gear; this device's adult pays the gems.
///
/// Framed in the pixel tier (wood board, parchment cards, wood buttons, gem
/// and material chips in the header); the text tier keeps its text panels.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/game_state.dart' show HeroState;
import '../domain/game_values.dart';
import '../game_sprite.dart';
import 'forge_gear_slot.dart';
import 'forge_hero_field.dart';
import 'hall_common.dart';
import 'hall_framed.dart';
import 'hall_ledger_view.dart';
import 'hall_resource_chips.dart';
import 'hall_voice.dart';
import 'kit/kit.dart';

/// The cosmetic fields the hero editor offers, in order.
const kHeroFields = [
  ('name', 'Hero name'),
  ('title', 'Title'),
  ('motto', 'Motto'),
];

/// The materials gear is made of, shown as chips in the header.
const _kGearMaterials = [
  MaterialKind.lumber,
  MaterialKind.ore,
  MaterialKind.hide,
  MaterialKind.herbs,
];

class ForgeScreen extends ConsumerStatefulWidget {
  const ForgeScreen({super.key});

  @override
  ConsumerState<ForgeScreen> createState() => _ForgeScreenState();
}

class _ForgeScreenState extends ConsumerState<ForgeScreen> {
  String? _heroId;
  final Map<String, String> _chosenType = {};

  @override
  Widget build(BuildContext context) {
    final game = hallGameState(ref);
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final now = ref.watch(gameClockProvider).now();
    final heroes = [
      for (final adult in view.adults)
        if (adult.inAdventure) adult,
    ];
    final heroId = _heroId ?? view.meId ?? '';
    final hero = game.person(heroId).hero;
    // The viewer's own town pays and forges, whoever's hero is chosen.
    final town = game.townOf(view.meId ?? '');
    final forgeTier = town.completedTier(BuildingType.forge, now);
    final isMe = heroId == view.meId;
    final heroName = hero.cosmetics['name'] ?? view.nameOf(heroId);
    final compact = MediaQuery.sizeOf(context).width < AdventureTokens.narrowScreen;

    return FramedHallScreen(
      title: 'Forge',
      trailing: [
        gemsChip(game.person(view.meId ?? '').gems, compact: compact),
        ...materialChips(town.materials, _kGearMaterials),
      ],
      children: [
        if (heroes.length > 1)
          Wrap(
            spacing: AdventureTokens.gap,
            runSpacing: AdventureTokens.gap,
            children: [
              for (final candidate in heroes)
                FramedChoice(
                  label: candidate.memberId == view.meId
                      ? '${candidate.name} (you)'
                      : candidate.name,
                  selected: candidate.memberId == heroId,
                  onSelected: () => setState(() => _heroId = candidate.memberId),
                ),
            ],
          ),
        FramedSection(
          title: 'The hero',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameSprite.fromKey(GameAssetKeys.heroPortrait,
                      label: heroName, baseSize: kPortraitBaseSize, scale: 2),
                  const SizedBox(width: AdventureTokens.gapLarge - 4),
                  Expanded(child: _HeroSummary(hero: hero, heroName: heroName)),
                ],
              ),
              const SizedBox(height: AdventureTokens.gap),
              Text(
                  'Every tier of gear adds 1 power: better finds on '
                  'expeditions and harder blows against the seasonal boss.',
                  style: framedMutedStyle(context)),
            ],
          ),
        ),
        if (isMe)
          FramedSection(
            title: 'Customize (free)',
            icon: Icons.brush_outlined,
            child: Column(
              children: [
                for (final field in kHeroFields)
                  ForgeHeroField(
                    key: ValueKey('hero-${field.$1}'),
                    field: field.$1,
                    label: field.$2,
                    initial: hero.cosmetics[field.$1] ?? '',
                  ),
              ],
            ),
          ),
        FramedSection(
          title: forgeTier == 0 ? 'The Forge' : 'The Forge — tier $forgeTier',
          icon: Icons.hardware_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (forgeTier == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AdventureTokens.gap),
                  child: Text(
                      'Build a Forge on any plot to start crafting gear. Gear '
                      'can never outrank the Forge.',
                      style: framedMutedStyle(context)),
                ),
              for (final (index, entry) in Balance.gearSlots.entries.indexed) ...[
                if (index > 0 && !hallTextTier(context))
                  const SizedBox(height: AdventureTokens.gap),
                ForgeGearSlot(
                  game: game,
                  heroId: heroId,
                  hero: hero,
                  slot: entry.key,
                  types: entry.value.gearTypes,
                  chosenType: _chosenType[entry.key],
                  onChooseType: (type) => setState(() => _chosenType[entry.key] = type),
                  voice: voice,
                  meId: view.meId,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// The hero's name, title, motto and power.
class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.hero, required this.heroName});

  final HeroState hero;
  final String heroName;

  @override
  Widget build(BuildContext context) {
    final title = hero.cosmetics['title'] ?? '';
    final motto = hero.cosmetics['motto'] ?? '';
    final text = hallTextTier(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heroName,
            style: text
                ? framedBodyStyle(context, weight: FontWeight.w800).copyWith(fontSize: 18)
                : AdventureTokens.title(context)),
        if (title.isNotEmpty) Text(title, style: framedBodyStyle(context)),
        if (motto.isNotEmpty) Text('"$motto"', style: framedMutedStyle(context)),
        const SizedBox(height: 4),
        if (text)
          Text('Power ${hero.power}', style: framedBodyStyle(context, weight: FontWeight.w700))
        else
          HudChip(
            icon: Icons.bolt,
            color: AdventureTokens.gold,
            value: '${hero.power}',
            label: 'power',
            valueKey: const ValueKey('forge-power'),
          ),
      ],
    );
  }
}
