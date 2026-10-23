/// The Forge & hero screen: the hero's look (free cosmetic fields), their
/// power, and the gear slots — current piece, the gear types each slot takes,
/// the next tier's cost, and why an upgrade can't happen yet. Anyone may pay
/// for anyone's gear; this device's adult pays the gems.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../config/balance.dart';
import '../data/game_providers.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../game_sprite.dart';
import 'hall_common.dart';
import 'hall_ledger_view.dart';
import 'hall_names.dart';
import 'hall_voice.dart';

/// The cosmetic fields the hero editor offers, in order.
const kHeroFields = [
  ('name', 'Hero name'),
  ('title', 'Title'),
  ('motto', 'Motto'),
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
    final clock = ref.watch(gameClockProvider);
    final now = clock.now();
    final heroes = [
      for (final a in view.adults)
        if (a.inAdventure) a,
    ];
    final heroId = _heroId ?? view.meId ?? '';
    final hero = game.person(heroId).hero;
    final forgeTier = game.hall.completedTier(BuildingType.forge, now);
    final isMe = heroId == view.meId;

    return Scaffold(
      appBar: AppBar(title: const Text('Forge & hero')),
      body: HallPage(children: [
        if (heroes.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final h in heroes)
                  ChoiceChip(
                    label: Text(h.memberId == view.meId ? '${h.name} (you)' : h.name),
                    selected: h.memberId == heroId,
                    onSelected: (_) => setState(() => _heroId = h.memberId),
                  ),
              ],
            ),
          ),
        HallSection(
          title: 'The hero',
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GameSprite.fromKey(GameAssetKeys.heroPortrait,
                      label: hero.cosmetics['name'] ?? view.nameOf(heroId),
                      baseSize: kPortraitBaseSize,
                      scale: 2),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(hero.cosmetics['name'] ?? view.nameOf(heroId),
                            style: hallBodyStyle(context, weight: FontWeight.w800)
                                .copyWith(fontSize: 18)),
                        if ((hero.cosmetics['title'] ?? '').isNotEmpty)
                          Text(hero.cosmetics['title']!,
                              style: hallBodyStyle(context)),
                        if ((hero.cosmetics['motto'] ?? '').isNotEmpty)
                          Text('"${hero.cosmetics['motto']}"',
                              style: hallMutedStyle(context)),
                        const SizedBox(height: AppSpacing.xs),
                        Text('Power ${hero.power}',
                            style: hallBodyStyle(context, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                  'Every tier of gear adds 1 power: better finds on '
                  'expeditions and harder blows against the seasonal boss.',
                  style: hallMutedStyle(context)),
            ],
          ),
        ),
        if (isMe)
          HallSection(
            title: 'Customize (free)',
            icon: Icons.brush_outlined,
            child: Column(
              children: [
                for (final f in kHeroFields)
                  _CosmeticField(
                    key: ValueKey('hero-${f.$1}'),
                    field: f.$1,
                    label: f.$2,
                    initial: hero.cosmetics[f.$1] ?? '',
                  ),
              ],
            ),
          ),
        HallSection(
          title: forgeTier == 0 ? 'The Forge' : 'The Forge — tier $forgeTier',
          icon: Icons.hardware_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (forgeTier == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                      'Build a Forge on any plot to start crafting gear. Gear '
                      'can never outrank the Forge.',
                      style: hallMutedStyle(context)),
                ),
              for (final slot in Balance.gearSlots.entries)
                _slotRow(context, game, heroId, slot.key, slot.value.gearTypes,
                    hero, voice, view.meId),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _slotRow(
    BuildContext context,
    GameState game,
    String heroId,
    String slot,
    List<String> types,
    HeroState hero,
    HallVoice voice,
    String? meId,
  ) {
    final clock = ref.read(gameClockProvider);
    final current = hero.gear[slot];
    final type = _chosenType[slot] ?? current?.gearType ?? types.first;
    final next = (current?.tier ?? 0) + 1;
    final atMax = next > Balance.maxGearTier;
    final rejection = atMax
        ? null
        : previewRejection(game, meId, clock,
            (c) => c.upgradeGear(heroId: heroId, slot: slot, gearType: type));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GameSprite.fromKey(GameAssetKeys.gear(slot, tier: current?.tier),
              label: HallNames.gearSlot(slot), scale: 2),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    current == null
                        ? '${HallNames.gearSlot(slot)}: empty'
                        : '${HallNames.gearSlot(slot)}: '
                            '${HallNames.gearType(current.gearType)} '
                            'T${current.tier}',
                    style: hallBodyStyle(context, weight: FontWeight.w700)),
                if (atMax)
                  Text('At its finest.', style: hallMutedStyle(context))
                else ...[
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final t in types)
                        ChoiceChip(
                          label: Text(HallNames.gearType(t)),
                          selected: t == type,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => _chosenType[slot] = t),
                        ),
                    ],
                  ),
                  CostLine(Balance.gearCost(slot, next),
                      label: 'Tier $next: '),
                  if (rejection != null)
                    Text(voice.rejection(rejection),
                        style: hallBodyStyle(context,
                            color: Theme.of(context).colorScheme.tertiary)),
                  const SizedBox(height: AppSpacing.xs),
                  FilledButton.tonal(
                    onPressed: rejection == null
                        ? () async {
                            final messenger = ScaffoldMessenger.maybeOf(context);
                            final r = await runHallCommand(
                                context,
                                ref,
                                (s) => s.upgradeGear(
                                    heroId: heroId, slot: slot, gearType: type));
                            if (r != null && r.accepted) {
                              messenger?.showSnackBar(SnackBar(
                                  content: Text('Forged: '
                                      '${HallNames.gearType(type)} T$next.')));
                            }
                          }
                        : null,
                    child: Text('Forge tier $next'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CosmeticField extends ConsumerStatefulWidget {
  const _CosmeticField({
    super.key,
    required this.field,
    required this.label,
    required this.initial,
  });

  final String field;
  final String label;
  final String initial;

  @override
  ConsumerState<_CosmeticField> createState() => _CosmeticFieldState();
}

class _CosmeticFieldState extends ConsumerState<_CosmeticField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: Balance.maxCosmeticValueLength,
                decoration: InputDecoration(
                  labelText: widget.label,
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                final r = await runHallCommand(
                    context,
                    ref,
                    (s) => s.customizeHero(
                        field: widget.field, value: _controller.text.trim()));
                if (r != null && r.accepted) {
                  messenger?.showSnackBar(
                      SnackBar(content: Text('${widget.label} saved.')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
}
