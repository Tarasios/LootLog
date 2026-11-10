/// The party frames around the dungeon floor: a wood board per adult with
/// their portrait, name and meter — stacked down the left on a wide screen,
/// a scrolling row of compact frames along the top on a narrow one. What each
/// frame shows comes from [dungeonPartyFrames]; nothing here computes it.
library;

import 'package:flutter/material.dart';

import '../../assets/pack_sprite.dart';
import '../kit/kit.dart';
import 'dungeon_party.dart';

/// The wide layout's column of party frames, under a small heading.
class DungeonPartyColumn extends StatelessWidget {
  const DungeonPartyColumn({super.key, required this.frames});

  final List<DungeonPartyFrame> frames;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          Text('The party', style: AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment)),
          const SizedBox(height: AdventureTokens.gap),
          for (final frame in frames)
            Padding(
              padding: const EdgeInsets.only(bottom: AdventureTokens.gap),
              child: _PartyFrameTile(frame: frame, compact: false),
            ),
        ],
      );
}

/// The narrow layout's row of compact party frames, scrolling sideways when
/// the party is larger than the screen.
class DungeonPartyRow extends StatelessWidget {
  const DungeonPartyRow({super.key, required this.frames});

  final List<DungeonPartyFrame> frames;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (index, frame) in frames.indexed) ...[
              if (index > 0) const SizedBox(width: AdventureTokens.gap),
              _PartyFrameTile(frame: frame, compact: true),
            ],
          ],
        ),
      );
}

/// One adult's frame: portrait, name, meter, and (when not [compact]) the
/// meter's caption. This adult's meter is mana blue (weapons swung); the
/// rest of the party stands at full green health.
class _PartyFrameTile extends StatelessWidget {
  const _PartyFrameTile({required this.frame, required this.compact});

  /// The width of a compact frame's name and meter.
  static const double _compactTextWidth = 96;

  final DungeonPartyFrame frame;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final lightLabel = AdventureTokens.label(context).copyWith(color: AdventureTokens.parchment);
    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(frame.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: lightLabel),
        const SizedBox(height: 4),
        MeterBar(
          fraction: frame.meterFraction,
          color: frame.isMe ? AdventureTokens.hpBlue : AdventureTokens.hpGreen,
          height: 8,
          semanticsLabel: '${frame.name}: ${frame.caption}',
        ),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(frame.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: lightLabel.copyWith(color: AdventureTokens.parchmentDark)),
        ],
      ],
    );
    return WoodPanel(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          InsetWell(
            padding: const EdgeInsets.all(4),
            // The name is on the frame already; the placeholder card (no art) names
            // only what the portrait is.
            child: PackSprite(
              assetKey: frame.portraitKey,
              label: frame.role == PartyFrameRole.caravan ? 'Wagon' : 'Hero',
            ),
          ),
          const SizedBox(width: AdventureTokens.gap),
          if (compact) SizedBox(width: _compactTextWidth, child: details) else Expanded(child: details),
        ],
      ),
    );
  }
}
