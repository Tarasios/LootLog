/// Dev tool: regenerates the neutral placeholder sprites in `assets/game/`.
///
/// The adventure skin ships with grey placeholder art so the pipeline is
/// exercised end-to-end before real pixel art exists. Each sprite is a 16×16
/// (per frame) PNG: a light-grey fill with a darker 1px border per frame so the
/// pixel grid and strip boundaries read. Drop real, correctly-named PNGs into
/// `assets/game/` to replace them — no code change needed.
///
/// Run from the `app/` directory: `dart run tool/generate_placeholder_sprites.dart`.
library;

import 'dart:io';

import 'package:image/image.dart' as img;

/// Sprite name (without extension) -> frame count. Mirrors `docs/art-assets.md`.
const _sprites = <String, int>{
  'hero_a_idle_4f': 4,
  'hero_b_idle_4f': 4,
  'monster_idle_4f': 4,
  'monster_enraged_4f': 4,
  'contract_seal_1f': 1,
  'pet_idle_4f': 4,
  'quest_monster_4f': 4,
  'trophy_1f': 1,
  'gold_pouch_1f': 1,
  'war_chest_1f': 1,
  'writ_1f': 1,
  'ransack_1f': 1,
  'reserve_cache_1f': 1,
  'anvil_1f': 1,
  'supplies_1f': 1,
  'coin_spin_6f': 6,
  'scroll_seal_1f': 1,
};

void main() {
  Directory('assets/game').createSync(recursive: true);
  _sprites.forEach((name, frames) {
    final width = 16 * frames;
    final image = img.Image(width: width, height: 16);
    for (var x = 0; x < width; x++) {
      for (var y = 0; y < 16; y++) {
        final fx = x % 16;
        final border = fx == 0 || fx == 15 || y == 0 || y == 15;
        final v = border ? 90 : 150;
        image.setPixelRgb(x, y, v, v, v);
      }
    }
    File('assets/game/$name.png')
        .writeAsBytesSync(img.PngEncoder().encode(image));
  });
  stdout.writeln('Generated ${_sprites.length} placeholder sprites.');
}
