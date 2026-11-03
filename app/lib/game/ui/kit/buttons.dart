/// The Adventure kit's buttons: the wood (or parchment) [WoodButton] for
/// dialogs and forms, the chunky [HudButton] for the town's corners, and
/// [KitPressable], the shared press behaviour under both (and under tappable
/// HUD chips).
///
/// Every kit button sets its own finite minimum size and never reads the
/// theme's button styles: `AppTheme` gives filled buttons a full-width
/// minimum, which fails layout in app-bar actions and rows (see 9751329).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;

import 'adventure_tokens.dart';
import 'pixel_frame.dart';

/// The smallest a [WoodButton] gets: a comfortable touch target.
const Size _kWoodButtonMinimum = Size(64, 44);

/// How far a pressed button's content sinks.
const double _kPressDepth = 2;

/// Disabled buttons draw at this opacity.
const double _kDisabledOpacity = 0.5;

/// The keyboard-focus ring drawn around a focused kit control.
const double _kFocusRingWidth = 2;

/// Builds a control's content; [pressed] is true while a pointer holds it down.
typedef KitPressableBuilder = Widget Function(BuildContext context, bool pressed);

/// Press behaviour for kit controls with no ink over the pixel art: tap and
/// keyboard activation, a focus ring, `button` semantics with an enabled
/// state, a dimmed look and no taps when [onPressed] is null, and a [builder]
/// told whether a pointer is holding the control down.
class KitPressable extends StatefulWidget {
  const KitPressable({
    super.key,
    required this.onPressed,
    required this.builder,
    this.semanticsLabel,
    this.minHitSize,
  });

  final VoidCallback? onPressed;
  final KitPressableBuilder builder;

  /// Overrides the label read from the content, e.g. to add a badge count.
  final String? semanticsLabel;

  /// Grows the tappable area (not the drawn control, which stays centred in
  /// it) to at least this size, for controls smaller than a touch target.
  final Size? minHitSize;

  @override
  State<KitPressable> createState() => _KitPressableState();
}

class _KitPressableState extends State<KitPressable> {
  bool _pressed = false;
  bool _focused = false;

  @override
  void didUpdateWidget(KitPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onPressed == null) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    Widget content = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: _focused
          ? BoxDecoration(
              border: Border.all(color: AdventureTokens.gold, width: _kFocusRingWidth),
            )
          : const BoxDecoration(),
      child: widget.builder(context, _pressed),
    );
    final minHitSize = widget.minHitSize;
    if (minHitSize != null) {
      content = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minHitSize.width, minHeight: minHitSize.height),
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
      );
    }
    // One merged node: label, button, enabled, focus and the tap action. The
    // tap action is set here too because a [semanticsLabel] excludes the
    // content's semantics, the InkWell's own action among them.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticsLabel,
        onTap: widget.onPressed,
        excludeSemantics: widget.semanticsLabel != null,
        child: Opacity(
          opacity: enabled ? 1 : _kDisabledOpacity,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (pressed) => setState(() => _pressed = pressed),
              onFocusChange: (focused) => setState(() => _focused = focused),
              splashFactory: NoSplash.splashFactory,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shifts [child] down by the press depth while [pressed], without changing
/// the control's size.
class _Sink extends StatelessWidget {
  const _Sink({required this.pressed, required this.child});

  final bool pressed;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Transform.translate(offset: Offset(0, pressed ? _kPressDepth : 0), child: child);
}

/// Which frame a [WoodButton] wears: wood for the main action, parchment for
/// the alternative (cancel, back, "not now").
enum WoodButtonTone { primary, secondary }

/// A framed text button with an optional leading icon. At least 64 × 44;
/// with [expand] it fills the available width (which must then be bounded).
class WoodButton extends StatelessWidget {
  const WoodButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = WoodButtonTone.primary,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final WoodButtonTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final primary = tone == WoodButtonTone.primary;
    final foreground = primary ? AdventureTokens.parchment : AdventureTokens.ink;
    final icon = this.icon;
    final button = KitPressable(
      onPressed: onPressed,
      builder: (context, pressed) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _kWoodButtonMinimum.width,
          minHeight: _kWoodButtonMinimum.height,
        ),
        child: PixelFrame(
          assetKey: primary ? KitKeys.wood : KitKeys.parchment,
          fallbackFill: primary ? AdventureTokens.wood : AdventureTokens.parchment,
          fallbackBorder: AdventureTokens.woodDark,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          // One rich text (icon as a span) rather than a row: it lays out in
          // unbounded slots such as app-bar actions, reports intrinsic sizes
          // for dialogs, and ellipsizes when the width runs out.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: _Sink(
              pressed: pressed,
              child: Text.rich(
                TextSpan(
                  children: [
                    if (icon != null) ...[
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(icon, size: 18, color: foreground),
                      ),
                      const WidgetSpan(child: SizedBox(width: 6)),
                    ],
                    TextSpan(text: label),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AdventureTokens.label(context).copyWith(color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// A chunky wood button for the town HUD's corners: the [icon] over a pixel
/// [label], or — when [large], for "Log purchase" — a wider button with the
/// icon beside a bigger label. A [badge] (a count, "!") rides the top-right
/// corner as a small red pill. The label ellipsizes when the width runs out;
/// a slot shorter than the content (fits a 56 px app bar) clips the label's
/// foot. The pixel font is never scaled, so it stays crisp.
class HudButton extends StatelessWidget {
  const HudButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.badge,
    this.large = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? badge;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final labelStyle = large
        ? AdventureTokens.title(context).copyWith(color: AdventureTokens.parchment)
        : AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment);
    // Rich text keeps the large button's icon and label on one line that
    // ellipsizes in a bounded width and lays out in an unbounded one.
    final content = large
        ? Text.rich(
            TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(icon, size: 28, color: AdventureTokens.parchment),
                ),
                const WidgetSpan(child: SizedBox(width: 8)),
                TextSpan(text: label),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: AdventureTokens.parchment),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: labelStyle),
            ],
          );
    final badge = this.badge;
    return KitPressable(
      onPressed: onPressed,
      semanticsLabel: badge == null ? label : '$label, $badge',
      builder: (context, pressed) => Stack(
        clipBehavior: Clip.none,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: large ? 140 : 56, minHeight: large ? 56 : 52),
            child: PixelFrame(
              assetKey: KitKeys.wood,
              fallbackFill: AdventureTokens.wood,
              fallbackBorder: AdventureTokens.woodDark,
              padding: large
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                // Clip rather than overflow (or scale the pixel font) when
                // the slot is shorter than the content.
                child: _Sink(
                  pressed: pressed,
                  child: ClipRect(
                    child: OverflowBox(
                      fit: OverflowBoxFit.deferToChild,
                      alignment: Alignment.topCenter,
                      minHeight: 0,
                      maxHeight: double.infinity,
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (badge != null) Positioned(top: -4, right: -4, child: _BadgePill(badge)),
        ],
      ),
    );
  }
}

/// The small red count pill on a [HudButton]'s corner.
class _BadgePill extends StatelessWidget {
  const _BadgePill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
    padding: const EdgeInsets.symmetric(horizontal: 5),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: AdventureTokens.ribbon,
      border: Border.all(color: AdventureTokens.woodDark, width: 2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(text, style: AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment)),
  );
}
