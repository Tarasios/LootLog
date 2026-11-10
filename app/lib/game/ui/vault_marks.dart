/// The milestone marks under a Vault meter: "[x] 25%  [x] 50%  [ ] 75%" as
/// text in the text tier, a row of small ticked boxes in the pixel tier.
library;

import 'package:flutter/material.dart';

import 'hall_common.dart';
import 'hall_framed.dart';
import 'kit/kit.dart';

class MilestoneMarks extends StatelessWidget {
  const MilestoneMarks({
    super.key,
    required this.marks,
    required this.reached,
    required this.label,
  });

  /// The milestone values, in ascending order.
  final List<int> marks;

  /// Whether the milestone [mark] has been reached.
  final bool Function(int mark) reached;

  /// The words for a milestone ("25%", "3 months").
  final String Function(int mark) label;

  @override
  Widget build(BuildContext context) {
    if (hallTextTier(context)) {
      return Text(
        [for (final mark in marks) '${reached(mark) ? '[x]' : '[ ]'} ${label(mark)}'].join('  '),
        style: hallMutedStyle(context),
      );
    }
    return Wrap(
      spacing: AdventureTokens.gapLarge,
      runSpacing: 4,
      children: [
        for (final mark in marks)
          Semantics(
            label: '${label(mark)}, ${reached(mark) ? 'reached' : 'not yet'}',
            excludeSemantics: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  reached(mark) ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: reached(mark) ? AdventureTokens.hpGreen : AdventureTokens.inkMuted,
                ),
                const SizedBox(width: 4),
                Text(label(mark), style: framedMutedStyle(context)),
              ],
            ),
          ),
      ],
    );
  }
}
