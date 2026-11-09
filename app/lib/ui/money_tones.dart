/// Semantic colours for money figures: the colour a gain (money coming in, a
/// rising balance, spending still within budget) is drawn in.
///
/// A theme may carry a [MoneyTones] extension; without one a gain is the
/// colour scheme's primary, which is what the Standard theme has always drawn
/// (so Standard renders exactly as before). The Adventure theme's primary is
/// ribbon red, so it supplies a green here: a gain must never read as a loss.
/// Losses keep the scheme's error colour in both themes.
library;

import 'package:flutter/material.dart';

class MoneyTones extends ThemeExtension<MoneyTones> {
  const MoneyTones({required this.gain});

  /// The colour of a gain.
  final Color gain;

  /// The gain colour of [context]'s theme: its [MoneyTones] if it has one,
  /// else the colour scheme's primary.
  static Color gainOf(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MoneyTones>()?.gain ?? theme.colorScheme.primary;
  }

  @override
  MoneyTones copyWith({Color? gain}) => MoneyTones(gain: gain ?? this.gain);

  @override
  MoneyTones lerp(MoneyTones? other, double t) =>
      other == null ? this : MoneyTones(gain: Color.lerp(gain, other.gain, t)!);
}
