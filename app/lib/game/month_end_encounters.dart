/// The month-end encounter walkthrough: before dividing the spoils, the party
/// replays the floor monster by monster. Spending *less* than a monster's max
/// HP is the win state — "it took less effort to fell it" — so a 0-spend
/// category is a flawless victory, not a wasted budget.
///
/// Pure pieces ([EncounterData], [buildEncounters], [EncounterLines]) are
/// Flutter-light and unit-tested; the screen only pages through them. Lines
/// load from `assets/game/text/encounter_lines.json` (data-driven, per the
/// narrative rule) — see `docs/voice-lines.md`.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart' hide Notification;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/money.dart';
import '../domain/state.dart';
import '../domain/time.dart';
import '../ui/theme.dart';
import 'adapter.dart' show Sprites;
import 'game_sprite.dart';
import 'game_state.dart';

/// One felled (or enraging) monster in the month-end replay.
class EncounterData {
  const EncounterData({
    required this.sliceId,
    required this.name,
    required this.maxHpCents,
    required this.spentCents,
    required this.isGroup,
  });

  final String sliceId;
  final String name;

  /// The monster's max HP: the category's effective limit that month.
  final int maxHpCents;

  /// Damage it took to fell it: what was spent.
  final int spentCents;
  final bool isGroup;

  int get leftoverCents => max(0, maxHpCents - spentCents);
  int get overspendCents => max(0, spentCents - maxHpCents);
  bool get flawless => spentCents == 0 && maxHpCents > 0;
  bool get enraged => overspendCents > 0;
}

/// Builds the encounter list for [month]: every category with a limit that
/// month that is [meUserId]'s own or the group's, group first then personal,
/// each alphabetical.
List<EncounterData> buildEncounters(
  HouseholdState state,
  Month month,
  String meUserId,
) {
  final out = <EncounterData>[];
  for (final cfg in state.slices.values) {
    if (cfg.createdMonth.isAfter(month)) continue;
    if (!cfg.isGroup && cfg.ownerUserId != meUserId) continue;
    final sm = state.sliceMonth(cfg.sliceId, month);
    final maxHp = sm?.effectiveLimitCents ?? cfg.baseEffectiveLimitCents;
    if (maxHp <= 0 && (sm?.spentCents ?? 0) <= 0) continue;
    out.add(EncounterData(
      sliceId: cfg.sliceId,
      name: cfg.name,
      maxHpCents: maxHp,
      spentCents: sm?.spentCents ?? 0,
      isGroup: cfg.isGroup,
    ));
  }
  out.sort((a, b) {
    final g = (a.isGroup ? 0 : 1).compareTo(b.isGroup ? 0 : 1);
    return g != 0 ? g : a.name.compareTo(b.name);
  });
  return out;
}

/// The data-driven encounter lines, keyed by outcome.
class EncounterLines {
  const EncounterLines({
    required this.flawless,
    required this.victory,
    required this.exact,
    required this.enraged,
  });

  final List<String> flawless;
  final List<String> victory;
  final List<String> exact;
  final List<String> enraged;

  static const assetPath = 'assets/game/text/encounter_lines.json';

  /// Parses the raw JSON document. Pure, so tests run against the shipped file.
  factory EncounterLines.parse(String json) {
    final map = jsonDecode(json) as Map;
    List<String> lines(String key) =>
        [for (final e in (map[key] as List? ?? const [])) e as String];
    return EncounterLines(
      flawless: lines('flawless'),
      victory: lines('victory'),
      exact: lines('exact'),
      enraged: lines('enraged'),
    );
  }

  static Future<EncounterLines> load([AssetBundle? bundle]) async =>
      EncounterLines.parse(
          await (bundle ?? rootBundle).loadString(assetPath));

  /// The narrated line for [e], placeholders filled. [rng] injectable.
  String lineFor(EncounterData e, {Random? rng}) {
    final pool = e.enraged
        ? enraged
        : e.flawless
            ? flawless
            : e.leftoverCents > 0
                ? victory
                : exact;
    if (pool.isEmpty) return '';
    final line = pool.length == 1
        ? pool.first
        : pool[(rng ?? Random()).nextInt(pool.length)];
    String money(int c) => '\$${Money(c).format()}';
    return line
        .replaceAll('{name}', e.name.toUpperCase())
        .replaceAll('{spent}', money(e.spentCents))
        .replaceAll('{leftover}', money(e.leftoverCents))
        .replaceAll('{limit}', money(e.maxHpCents))
        .replaceAll('{over}', money(e.overspendCents));
  }
}

/// Full-screen pager: one page per monster, ending in [onFinished] (which
/// opens the divide-the-spoils sheet). Pure display — appends nothing.
class MonthEndEncountersScreen extends StatefulWidget {
  const MonthEndEncountersScreen({
    super.key,
    required this.encounters,
    required this.lines,
    required this.monthLabel,
    required this.onFinished,
    this.resolver = const PlaceholderSpriteResolver(),
  });

  final List<EncounterData> encounters;
  final EncounterLines lines;
  final String monthLabel;
  final VoidCallback onFinished;
  final SpriteResolver resolver;

  @override
  State<MonthEndEncountersScreen> createState() =>
      _MonthEndEncountersScreenState();
}

class _MonthEndEncountersScreenState extends State<MonthEndEncountersScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == widget.encounters.length - 1;

  void _next() {
    if (_isLast) {
      widget.onFinished();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Floor cleared — ${widget.monthLabel}'),
        actions: [
          TextButton(
            onPressed: widget.onFinished,
            child: const Text('Skip to spoils'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: [
                  for (final e in widget.encounters)
                    _EncounterPage(
                      encounter: e,
                      line: widget.lines.lineFor(e),
                      resolver: widget.resolver,
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Text('${_index + 1} / ${widget.encounters.length}'),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _next,
                    icon: Icon(
                        _isLast ? Icons.auto_awesome : Icons.arrow_forward),
                    label:
                        Text(_isLast ? 'Divide the spoils' : 'Next encounter'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EncounterPage extends StatelessWidget {
  const _EncounterPage({
    required this.encounter,
    required this.line,
    required this.resolver,
  });

  final EncounterData encounter;
  final String line;
  final SpriteResolver resolver;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = encounter;
    final hpFrac = e.maxHpCents <= 0
        ? 1.0
        : (e.spentCents / e.maxHpCents).clamp(0.0, 1.0);
    String money(int c) => '\$${Money(c).format()}';
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GameSprite(
                sprite: SpriteRef.asset(
                  e.enraged ? Sprites.monsterEnraged : Sprites.monster,
                  label: e.name,
                ),
                resolver: resolver,
                scale: 4,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                e.name.toUpperCase(),
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: hpFrac,
                  minHeight: 10,
                  color: e.enraged ? scheme.error : scheme.primary,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${money(e.spentCents)} damage dealt of ${money(e.maxHpCents)} max HP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                line,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
