// ignore_for_file: avoid_print
/// Generates LootLog's placeholder app icon and splash logo, then writes the
/// platform-specific launcher-icon sizes. Real branding just replaces the
/// generated PNGs (or the drawing here) and re-runs this — no code changes.
///
/// Run from `app/`: `dart run tool/generate_branding.dart`.
///
/// It writes:
///  * `assets/branding/app_icon.png`     (1024²  master icon)
///  * `assets/branding/splash_logo.png`  (512²   transparent splash mark)
///  * Android `res/mipmap-*/ic_launcher.png` at every density
///  * Android `res/drawable*/splash_logo.png` for the launch screen
///  * macOS `AppIcon.appiconset/app_icon_*.png` at every size
library;

import 'dart:io';

import 'package:image/image.dart' as img;

// LootLog mark: two overlapping "coins" (the two members) on a deep slate
// field — a placeholder that reads as a shared purse without any real artwork.
const int _bg1 = 0xFF1F2A44; // slate top
const int _bg2 = 0xFF16233B; // slate bottom
const int _goldA = 0xFFE8B84B; // member A coin
const int _goldB = 0xFFF2CE7A; // member B coin
const int _rim = 0xFF3A2E12; // coin rim

void main() {
  final master = _drawIcon(1024);
  _writePng(master, 'assets/branding/app_icon.png');

  final splash = _drawLogo(512);
  _writePng(splash, 'assets/branding/splash_logo.png');

  // Android launcher icons.
  const androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  androidSizes.forEach((dir, size) {
    final resized = img.copyResize(master, width: size, height: size);
    _writePng(resized, 'android/app/src/main/res/$dir/ic_launcher.png');
  });

  // Android splash logo (used by the launch_background drawable).
  for (final dir in ['drawable', 'drawable-v21']) {
    _writePng(
      img.copyResize(splash, width: 288, height: 288),
      'android/app/src/main/res/$dir/splash_logo.png',
    );
  }

  // macOS app-icon set (filenames referenced by Contents.json).
  const macSizes = [16, 32, 64, 128, 256, 512, 1024];
  for (final size in macSizes) {
    final resized = img.copyResize(master, width: size, height: size);
    _writePng(
      resized,
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_$size.png',
    );
  }

  print('Branding regenerated.');
}

img.Image _drawIcon(int n) {
  final image = img.Image(width: n, height: n);
  // Vertical slate gradient background.
  for (var y = 0; y < n; y++) {
    final t = y / (n - 1);
    final c = _lerp(_bg1, _bg2, t);
    for (var x = 0; x < n; x++) {
      image.setPixelRgba(x, y, (c >> 16) & 0xFF, (c >> 8) & 0xFF, c & 0xFF, 0xFF);
    }
  }
  _drawCoins(image, n, opaqueField: true);
  return image;
}

img.Image _drawLogo(int n) {
  final image = img.Image(width: n, height: n, numChannels: 4);
  // Transparent field for the splash mark.
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));
  _drawCoins(image, n, opaqueField: false);
  return image;
}

void _drawCoins(img.Image image, int n, {required bool opaqueField}) {
  final r = (n * 0.26).round();
  final cy = (n * 0.5).round();
  final ax = (n * 0.40).round();
  final bx = (n * 0.60).round();
  // Back coin (member B), then front coin (member A) overlapping it.
  _coin(image, bx, cy, r, _goldB);
  _coin(image, ax, cy, r, _goldA);
}

void _coin(img.Image image, int cx, int cy, int r, int fill) {
  img.fillCircle(image, x: cx, y: cy, radius: r, color: _rgb(fill));
  img.drawCircle(image, x: cx, y: cy, radius: r, color: _rgb(_rim));
  // Inner ring for a minted look.
  img.drawCircle(image,
      x: cx, y: cy, radius: (r * 0.72).round(), color: _rgb(_rim));
}

img.ColorRgb8 _rgb(int argb) =>
    img.ColorRgb8((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF);

int _lerp(int a, int b, double t) {
  int chan(int shift) {
    final av = (a >> shift) & 0xFF;
    final bv = (b >> shift) & 0xFF;
    return (av + (bv - av) * t).round() & 0xFF;
  }

  return (chan(16) << 16) | (chan(8) << 8) | chan(0);
}

void _writePng(img.Image image, String path) {
  final file = File(path)..parent.createSync(recursive: true);
  file.writeAsBytesSync(img.encodePng(image));
  print('  wrote $path (${image.width}x${image.height})');
}
