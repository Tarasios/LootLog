/// The month-end dungeon's battle screen, laid out like a pixel dungeon
/// crawler on dark stone: party frames, the floor in an ornate frame, the
/// turn (weapon card and targets, or the victory tally) and the adventure
/// log in an inset well.
///
/// Wide (≥ [AdventureTokens.wideBreakpoint]): party down the left, the floor under
/// its month ribbon in the middle, the turn on the right, the log across the
/// bottom. Narrow: a row of compact party frames on top, then the floor, the
/// turn and the log.
///
/// The frame hugs the floor at the largest whole zoom that fits (no black
/// bars); on a phone the floor gets its 2× zoom first and the turn takes the
/// rest, scrolling inside itself when it needs to.
library;

import 'package:flutter/material.dart';

import '../../scenes/camera_controls.dart' show kTileSize;
import '../../scenes/dungeon/dungeon_game.dart';
import '../kit/kit.dart';
import 'dungeon_party.dart';
import 'dungeon_party_frames.dart';

/// The arrangement of one battle screen; every piece is built by the caller.
/// The [turn] gets a bounded height and handles its own overflow.
class DungeonBattleLayout extends StatelessWidget {
  const DungeonBattleLayout({
    super.key,
    required this.party,
    required this.floor,
    required this.floorRows,
    required this.floorTitle,
    required this.turn,
    required this.logLines,
  });

  final List<DungeonPartyFrame> party;

  /// The scene (or its stand-in while it loads), framed here.
  final Widget floor;

  /// The scene's height in tiles ([DungeonGame.rows]), to size the frame.
  final int floorRows;

  /// The ribbon over the floor on a wide screen: the month being divided.
  final String floorTitle;

  /// The weapon card and targets, or the victory tally.
  final Widget turn;

  /// The adventure log, oldest first.
  final List<String> logLines;

  /// The wide layout's side columns and the log's heights.
  static const double _partyWidth = 240;
  static const double _turnWidth = 360;
  static const double _wideLogHeight = 136;
  static const double _narrowLogHeight = 72;

  /// The narrow layout's party row height, and the least height the turn
  /// keeps (the weapon card, a row of targets and Strike).
  static const double _narrowPartyHeight = 56;
  static const double _narrowTurnMinimum = 260;

  /// The month ribbon's height (see [RibbonTitle]).
  static const double _ribbonHeight = 64;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= AdventureTokens.wideBreakpoint;
        return wide ? _wide() : _narrow(constraints);
      });

  Widget _wide() => Padding(
        padding: const EdgeInsets.all(AdventureTokens.gapLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: _partyWidth, child: DungeonPartyColumn(frames: party)),
                  const SizedBox(width: AdventureTokens.gapLarge),
                  Expanded(
                    child: LayoutBuilder(builder: (context, area) {
                      final floorArea = Size(area.maxWidth, area.maxHeight - _ribbonHeight - AdventureTokens.gap);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RibbonTitle(floorTitle),
                          const SizedBox(height: AdventureTokens.gap),
                          DungeonViewport(rows: floorRows, area: floorArea, scale: 2, child: floor),
                        ],
                      );
                    }),
                  ),
                  const SizedBox(width: AdventureTokens.gapLarge),
                  SizedBox(width: _turnWidth, child: Align(alignment: Alignment.topCenter, child: turn)),
                ],
              ),
            ),
            const SizedBox(height: AdventureTokens.gapLarge),
            SizedBox(height: _wideLogHeight, child: AdventureLogWell(lines: logLines)),
          ],
        ),
      );

  Widget _narrow(BoxConstraints constraints) {
    const padding = AdventureTokens.gap;
    const gaps = 3 * AdventureTokens.gap;
    final floorArea = Size(
      constraints.maxWidth - 2 * padding,
      constraints.maxHeight - 2 * padding - gaps - _narrowPartyHeight - _narrowLogHeight - _narrowTurnMinimum,
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: _narrowPartyHeight, child: DungeonPartyRow(frames: party)),
            const SizedBox(height: AdventureTokens.gap),
            DungeonViewport(rows: floorRows, area: floorArea, scale: 1, child: floor),
            const SizedBox(height: AdventureTokens.gap),
            Expanded(child: Align(alignment: Alignment.topCenter, child: turn)),
            const SizedBox(height: AdventureTokens.gap),
            SizedBox(height: _narrowLogHeight, child: AdventureLogWell(lines: logLines)),
          ],
        ),
      ),
    );
  }
}

/// The floor in the ornate frame, sized to the floor at the largest whole
/// zoom that fits [area] and centred in it. [scale] is the frame's
/// whole-number magnification: 1 on a phone, so the floor keeps its 2× zoom.
class DungeonViewport extends StatelessWidget {
  const DungeonViewport({
    super.key,
    required this.child,
    required this.rows,
    required this.area,
    this.scale = 2,
  });

  /// The ornate frame's 9-slice inset, in source pixels.
  static const int _frameBorder = 10;

  final Widget child;
  final int rows;

  /// The room the frame may take, frame included.
  final Size area;
  final int scale;

  @override
  Widget build(BuildContext context) {
    final frame = (_frameBorder * scale).toDouble();
    final inner = Size(
      (area.width - 2 * frame).clamp(0, double.infinity),
      (area.height - 2 * frame).clamp(0, double.infinity),
    );
    final zoom = DungeonGame.fitZoom(inner, rows);
    // As wide as the whole floor, or as much as there is (the floor's bare
    // side margins may be cropped); always the floor's full height.
    final floorWidth = (DungeonGame.columns * kTileSize * zoom).clamp(0, inner.width).toDouble();
    final floorHeight = rows * kTileSize * zoom;
    return Center(
      child: PixelFrame(
        assetKey: KitKeys.ornate,
        border: _frameBorder,
        scale: scale,
        fallbackFill: AdventureTokens.woodDark,
        fallbackBorder: AdventureTokens.wood,
        padding: EdgeInsets.all(frame),
        child: SizedBox(width: floorWidth, height: floorHeight, child: ClipRect(child: child)),
      ),
    );
  }
}

/// The adventure log: an inset well of game-voice lines, newest at the
/// bottom and kept in view (a short log sits at the top). The newest line
/// carries the `dungeon-log` key.
///
/// The scroll area is a whole number of lines tall, with the spare height as
/// padding above it, so the oldest line in view is never cut in half.
class AdventureLogWell extends StatelessWidget {
  const AdventureLogWell({super.key, required this.lines});

  final List<String> lines;

  /// Each line's height, as a multiple of the font size (the gap between
  /// lines is part of it, so every entry is a whole number of lines tall).
  static const double _lineHeightFactor = 1.6;

  static const EdgeInsets _wellPadding = EdgeInsets.fromLTRB(12, 8, 12, 8);

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdventureTokens.ink);
    final fontSize = style?.fontSize ?? 14;
    final strut = StrutStyle(fontSize: fontSize, height: _lineHeightFactor, forceStrutHeight: true);
    final lineHeight = _measureLineHeight(context, style, strut);
    final newestFirst = lines.reversed.toList();
    return InsetWell(
      padding: _wellPadding,
      child: LayoutBuilder(builder: (context, area) {
        final room = area.maxHeight;
        final wholeLines = room.isFinite ? (room / lineHeight).floor() : null;
        final scrollHeight = wholeLines == null ? null : wholeLines * lineHeight;
        return Padding(
          padding: EdgeInsets.only(top: scrollHeight == null ? 0 : room - scrollHeight),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: scrollHeight ?? double.infinity),
              child: ListView.builder(
                reverse: true,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: newestFirst.length,
                itemBuilder: (context, index) => Text(
                  newestFirst[index],
                  key: index == 0 ? const ValueKey('dungeon-log') : null,
                  strutStyle: strut,
                  style: index == 0 ? style?.copyWith(fontWeight: FontWeight.bold) : style,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// One laid-out line's height (the engine rounds the strut's metrics).
  static double _measureLineHeight(BuildContext context, TextStyle? style, StrutStyle strut) {
    final painter = TextPainter(
      text: TextSpan(text: 'M', style: style),
      strutStyle: strut,
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}
