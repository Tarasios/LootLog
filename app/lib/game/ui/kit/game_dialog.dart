/// The Adventure pop-up: a wood board with a ribbon title riding its top
/// edge, an optional scene strip, a parchment body that scrolls when tall,
/// and a row of wood buttons — the framed dialogs of a village-builder game.
/// [showGameDialog] opens one as a route with a dimmed barrier and a quick
/// scale-and-fade.
library;

import 'package:flutter/material.dart';

import '../../assets/game_asset_scope.dart';
import 'adventure_tokens.dart';
import 'buttons.dart';
import 'panels.dart';
import 'pixel_frame.dart';

/// The ribbon banner's height (see [RibbonTitle]); the dialog's board starts
/// half of it below the top so the ribbon straddles the board's edge.
const double _kRibbonHeight = 64;

/// The height of the optional scene strip.
const double _kSceneHeight = 120;

/// Screens narrower than this stack the actions full width.
const double _kNarrowScreen = 420;

/// The close button's square size: a comfortable touch target.
const double _kCloseSize = 44;

/// Keeps the dialog off the screen edges.
const EdgeInsets _kScreenMargin = EdgeInsets.all(16);

/// How long the dialog takes to scale and fade in (and out).
const Duration _kTransition = Duration(milliseconds: 160);

/// A framed game dialog: [title] on a ribbon over a [WoodPanel], an optional
/// [scene] strip in an [InsetWell], [body] on a [ParchmentCard] (scrollable
/// when the screen is short), and [actions] — usually [WoodButton]s — right
/// aligned in a wrapping row, or stacked full width on a narrow screen. With
/// [onClose] an X button sits on the board's top-right corner. At most
/// [maxWidth] wide.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    required this.body,
    this.scene,
    this.actions = const [],
    this.onClose,
    this.maxWidth = 520,
  });

  final String title;
  final Widget body;
  final Widget? scene;
  final List<Widget> actions;
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final onClose = this.onClose;
    // Leave the corner clear for the X; with no X a long title may use the
    // board's whole width.
    final ribbonInset = onClose == null ? 16.0 : _kCloseSize + 16;
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AdventureTokens.ink),
        child: Center(
          child: Padding(
            padding: _kScreenMargin,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: _kRibbonHeight / 2),
                    child: WoodPanel(
                      padding: const EdgeInsets.fromLTRB(12, _kRibbonHeight / 2 + 12, 12, 12),
                      child: _DialogContents(scene: scene, body: body, actions: actions),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: ribbonInset,
                    right: ribbonInset,
                    child: Center(child: RibbonTitle(title)),
                  ),
                  // Like the ribbon, the X straddles the board's top edge, so
                  // it stays clear of the scene well and the body below.
                  if (onClose != null)
                    Positioned(
                      top: (_kRibbonHeight - _kCloseSize) / 2,
                      right: 6,
                      child: _CloseButton(onPressed: onClose),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scene, body and actions, stacked. Given a bounded height (a route) the
/// body shrinks and scrolls; unbounded (inline in a scroll view) it takes its
/// natural height.
class _DialogContents extends StatelessWidget {
  const _DialogContents({required this.scene, required this.body, required this.actions});

  final Widget? scene;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final scene = this.scene;
        final card = ParchmentCard(child: SingleChildScrollView(child: body));
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (scene != null) ...[
              InsetWell(
                padding: const EdgeInsets.all(6),
                child: SizedBox(height: _kSceneHeight, child: ClipRect(child: scene)),
              ),
              const SizedBox(height: AdventureTokens.gap),
            ],
            if (constraints.hasBoundedHeight) Flexible(child: card) else card,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AdventureTokens.gapLarge - 4),
              _ActionBar(actions: actions),
            ],
          ],
        );
      });
}

/// The dialog's buttons: right aligned and wrapping on a wide screen, stacked
/// full width (in the order given) on a narrow one.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < _kNarrowScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The last action is the main one (it sits at the right on a wide
          // screen), so stacked on a phone it comes first, under the thumb's
          // reading order: the main action on top, the way out below it.
          for (final (index, action) in actions.reversed.indexed) ...[
            if (index > 0) const SizedBox(height: AdventureTokens.gap),
            action,
          ],
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: AdventureTokens.gap,
      runSpacing: AdventureTokens.gap,
      children: actions,
    );
  }
}

/// The square wood X in the dialog's corner.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => KitPressable(
        onPressed: onPressed,
        semanticsLabel: MaterialLocalizations.of(context).closeButtonLabel,
        builder: (context, pressed) => SizedBox.square(
          key: const ValueKey('game-dialog-close'),
          dimension: _kCloseSize,
          child: PixelFrame(
            assetKey: KitKeys.wood,
            fallbackFill: AdventureTokens.wood,
            fallbackBorder: AdventureTokens.woodDark,
            padding: EdgeInsets.zero,
            child: Transform.translate(
              offset: Offset(0, pressed ? 2 : 0),
              child: const Icon(Icons.close, size: 24, color: AdventureTokens.parchment),
            ),
          ),
        ),
      );
}

/// Opens the dialog [builder] makes as a route over a dimmed barrier, scaling
/// and fading in over 160 ms. Tapping the barrier or pressing Escape closes it
/// when [barrierDismissible]. The dialog sits under an [AdventureSpriteScope],
/// so pack art (and the device's text tier) resolves inside the route.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: _kTransition,
      pageBuilder: (routeContext, animation, secondaryAnimation) =>
          SafeArea(child: AdventureSpriteScope(child: Builder(builder: builder))),
      transitionBuilder: (routeContext, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
