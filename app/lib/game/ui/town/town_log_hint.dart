/// A muted note in the HUD's Log purchase corner, such as "Log today to
/// open the town": a quiet parchment plate, never a warning.
library;

import 'package:flutter/material.dart';

import '../kit/kit.dart';

class TownLogHint extends StatelessWidget {
  const TownLogHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: AdventureTokens.parchment.withValues(alpha: 0.85),
      border: Border.all(color: AdventureTokens.woodDark),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_twilight, size: 16, color: AdventureTokens.inkMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AdventureTokens.label(context).copyWith(color: AdventureTokens.inkMuted),
            ),
          ),
        ],
      ),
    ),
  );
}
