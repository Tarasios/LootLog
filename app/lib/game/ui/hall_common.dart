/// Shared plumbing for the guild-hall screens: the links out to the ledger,
/// the tier-aware section frame, material and cost lines, the command runner
/// (rejections become friendly snackbars), dry-run previews of a command, the
/// celebration dialog, and a ticker for countdowns.
///
/// Every screen renders in both tiers: the text tier (the default while art
/// is placeholder) is a first-class text-adventure look, and the pixel tier
/// draws the same structure around `GameSprite`s (which still fall back to
/// their text cards per asset when no art exists).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/time.dart';
import '../../ui/theme.dart';
import '../assets/asset_catalog.dart';
import '../assets/asset_key.dart';
import '../assets/game_asset_scope.dart';
import '../data/game_providers.dart';
import '../domain/clock.dart';
import '../domain/commands/game_commands.dart';
import '../domain/game_event_stamp.dart';
import '../domain/game_state.dart';
import '../domain/game_values.dart';
import '../game_sprite.dart';
import '../skin_prefs.dart';
import '../text_mode/text_widgets.dart';
import 'hall_names.dart';
import 'hall_voice.dart';

/// A ledger action that needs a context to navigate from.
typedef HallContextAction = void Function(BuildContext context);

/// A ledger action about one closed month.
typedef HallMonthAction = void Function(BuildContext context, Month month);

/// Where the hall hands off to the budgeting app. The hall never depends on
/// the app shell or the ledger screens; the launch gate wires these in. Any
/// link left null falls back to opening the ledger.
class HallLinks {
  const HallLinks({
    this.logPurchase,
    this.reconcileMonth,
    this.reviewMonth,
    this.planMonth,
    this.divideLeftovers,
  });

  /// Opens quick entry straight away (one tap from the hall).
  final HallContextAction? logPurchase;

  /// Ritual step 1: checking the month's entries and bill actuals.
  final HallMonthAction? reconcileMonth;

  /// Ritual step 2: the month report.
  final HallMonthAction? reviewMonth;

  /// Ritual step 3: budget setup for the month ahead.
  final HallMonthAction? planMonth;

  /// Ritual step 4: dividing the month's leftovers.
  final HallMonthAction? divideLeftovers;

  HallMonthAction? forStep(RitualStep step) => switch (step) {
        RitualStep.reconcile => reconcileMonth,
        RitualStep.review => reviewMonth,
        RitualStep.plan => planMonth,
        RitualStep.contribute => divideLeftovers,
      };
}

/// Whether the hall is drawn in the text tier here.
bool hallTextTier(BuildContext context) =>
    GameSpriteScope.maybeOf(context)?.tier == AdventureTier.text;

/// The body style for hall copy: monospace in the text tier.
TextStyle hallBodyStyle(BuildContext context, {Color? color, FontWeight? weight}) {
  if (hallTextTier(context)) {
    return monoStyle(context, color: color, weight: weight);
  }
  return Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(color: color, fontWeight: weight);
}

/// A muted secondary style.
TextStyle hallMutedStyle(BuildContext context) => hallBodyStyle(context,
    color: Theme.of(context).colorScheme.onSurfaceVariant);

/// One titled section of a hall screen: a [TextPanel] in the text tier, a
/// framed card in the pixel tier.
class HallSection extends StatelessWidget {
  const HallSection({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.accent,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      return TextPanel(
        title: title,
        icon: icon,
        accent: accent,
        trailing: trailing,
        child: child,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final tint = accent ?? scheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadii.card,
        border: Border.all(color: tint.withValues(alpha: 0.35), width: 2),
        color: scheme.surfaceContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.md)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: tint),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: tint, fontWeight: FontWeight.w800),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A material bundle: "12 lumber, 4 stone" in the text tier, sprite icons
/// with counts in the pixel tier.
class MaterialLine extends StatelessWidget {
  const MaterialLine(this.bundle, {super.key, this.prefix = ''});

  final MaterialBundle bundle;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context) || bundle.isEmpty) {
      return Text('$prefix${HallNames.bundle(bundle)}',
          style: hallBodyStyle(context));
    }
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (prefix.isNotEmpty) Text(prefix.trim(), style: hallBodyStyle(context)),
        for (final e in bundle.amounts.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameSprite.fromKey(GameAssetKeys.material(e.key),
                  scale: 1, semanticLabel: HallNames.material(e.key)),
              const SizedBox(width: AppSpacing.xs),
              Text('${e.value} ${HallNames.material(e.key)}',
                  style: hallBodyStyle(context)),
            ],
          ),
      ],
    );
  }
}

/// A cost: "15 gems + 20 lumber" / "Free".
class CostLine extends StatelessWidget {
  const CostLine(this.cost, {super.key, this.label = 'Cost: '});

  final Loot cost;
  final String label;

  @override
  Widget build(BuildContext context) =>
      Text('$label${HallNames.cost(cost)}', style: hallBodyStyle(context));
}

/// The game's current instant.
DateTime hallNow(WidgetRef ref) => ref.watch(gameClockProvider).now();

/// Runs [command] for this device's adult. A rejection shows its friendly
/// copy in a snackbar; the result is returned either way (null before setup).
Future<GameCommandResult?> runHallCommand(
  BuildContext context,
  WidgetRef ref,
  Future<GameCommandResult> Function(GameCommandsService service) command,
) async {
  final service = ref.read(gameCommandsServiceProvider);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final voice = ref.read(hallVoiceProvider).value ?? HallVoice.empty;
  if (service == null) {
    messenger?.showSnackBar(const SnackBar(
        content: Text('Finish setting up the household first.')));
    return null;
  }
  final result = await command(service);
  if (!result.accepted) {
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
        SnackBar(content: Text(voice.rejection(result.rejection!))));
  }
  return result;
}

/// Dry-runs a command against [state] without writing anything, returning
/// why it would be refused (null when it would be accepted). The UI uses it
/// to enable buttons and explain gates in the same words the command would.
GameRejection? previewRejection(
  GameState state,
  String? actorId,
  Clock clock,
  GameCommandResult Function(GameCommands commands) command,
) {
  if (actorId == null) return null;
  return command(GameCommands(
    state: state,
    clock: clock,
    actorId: actorId,
    stamp: GameEventStamp(deviceId: 'preview', newEventId: () => 'preview'),
  )).rejection;
}

/// A small celebration: a sprite, a headline, and what was rolled.
Future<void> showHallCelebration(
  BuildContext context, {
  required AssetKey sprite,
  required String title,
  List<String> lines = const [],
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => HallScope(
        child: Builder(
          builder: (context) => AlertDialog(
            icon: GameSprite.fromKey(sprite, scale: 3),
            title: Text(title, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final l in lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text(l,
                        textAlign: TextAlign.center,
                        style: hallBodyStyle(context)),
                  ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Huzzah!'),
              ),
            ],
          ),
        ),
      ),
    );

/// Rebuilds [builder] every [period] so countdowns stay fresh. The timer is
/// cancelled with the widget.
class HallTicker extends StatefulWidget {
  const HallTicker({
    super.key,
    required this.builder,
    this.period = const Duration(seconds: 30),
  });

  final WidgetBuilder builder;
  final Duration period;

  @override
  State<HallTicker> createState() => _HallTickerState();
}

class _HallTickerState extends State<HallTicker> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.period, (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

/// The root of every hall surface (home, pushed screens, sheets, dialogs):
/// sprites follow the device's tier, and filled buttons size to their label
/// (the app theme makes them full-width, which suits forms but not the
/// hall's rows of actions).
class HallScope extends StatelessWidget {
  const HallScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 44),
            shape: const RoundedRectangleBorder(borderRadius: AppRadii.card),
          ),
        ),
      ),
      child: AdventureSpriteScope(child: child),
    );
  }
}

/// Pushes a hall screen, wrapped so its sprites follow the device's tier.
Future<void> pushHallScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (_) => HallScope(child: screen),
    ));

/// The hall's projected state, or the starting hall while it loads.
GameState hallGameState(WidgetRef ref) =>
    ref.watch(gameStateProvider).value ?? GameState.initial();

/// A centred column capped at a readable width, for pushed hall screens.
class HallPage extends StatelessWidget {
  const HallPage({super.key, required this.children, this.maxWidth = 720});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
}

/// A block-character bar in the text tier, a progress bar in the pixel tier.
class HallBar extends StatelessWidget {
  const HallBar(this.fraction, {super.key, this.width = 12});

  final double fraction;
  final int width;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    if (hallTextTier(context)) {
      return Text(textBar(f, width: width),
          style: monoStyle(context,
              color: Theme.of(context).colorScheme.primary));
    }
    return SizedBox(
      width: width * 8.0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: f, minHeight: 8),
      ),
    );
  }
}
