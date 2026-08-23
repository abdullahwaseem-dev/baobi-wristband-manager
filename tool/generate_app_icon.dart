// ignore_for_file: avoid_print — build-time CLI script, stdout is the UI.
// Regenerates windows/runner/resources/app_icon.ico from the Baobi logo,
// replacing Flutter's default icon. That one .ico drives the exe icon, the
// window icon, the taskbar, and the installer (baobi_setup.iss points
// SetupIconFile at it), so it's the only file that needs to change.
//
// The logo is a wide wordmark, which is the whole problem: squeezed into a
// square it's ~3px tall at 16x16 and unreadable. An ICO can hold a different
// image per size, so this builds two treatments — the full wordmark at the
// large sizes where it fits, and just the "B" at the small ones where it
// doesn't. The "B" is cropped from the logo itself rather than drawn from a
// font, so it stays genuinely their mark.
//
// Run with:
//   dart run tool/generate_app_icon.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const _logoPath = 'assets/images/baobi_logo.png';
const _icoPath = 'windows/runner/resources/app_icon.ico';

/// Windows uses 16/32/48 in Explorer and the taskbar, 256 for the large tile.
/// 24/64/128 fill the gaps so nothing has to be downscaled on the fly.
const _sizes = [16, 24, 32, 48, 64, 128, 256];

/// Below this, the five-letter wordmark stops being legible and the icon
/// switches to the "B" alone.
const _wordmarkMinSize = 64;

void main() async {
  final logo = img.decodePng(await File(_logoPath).readAsBytes());
  if (logo == null) {
    stderr.writeln('Could not decode $_logoPath');
    exitCode = 1;
    return;
  }
  print('Logo: ${logo.width}x${logo.height}, hasAlpha=${logo.hasAlpha}');

  final mark = _asMask(logo);
  final brand = _dominantColour(logo);
  print('Brand colour: #${_hex(brand)}');

  final letter = _firstGlyph(mark);
  print('First glyph ("B"): ${letter.width}x${letter.height}');

  final frames = <img.Image>[
    for (final s in _sizes) _tile(s, s >= _wordmarkMinSize ? mark : letter, brand),
  ];

  // The multi-frame ICO encoder isn't exported from package:image's barrel, so
  // the public route in is an Image carrying the rest as animation frames —
  // encodeIco writes each frame at its own size, which is exactly an icon set.
  final doc = frames.first;
  for (final f in frames.skip(1)) {
    doc.addFrame(f);
  }

  final ico = img.encodeIco(doc);
  await File(_icoPath).writeAsBytes(ico);
  print('Wrote $_icoPath (${ico.length} bytes, ${frames.length} sizes: '
      '${_sizes.join(", ")})');
}

String _hex(img.Color c) => [c.r, c.g, c.b]
    .map((v) => v.toInt().toRadixString(16).padLeft(2, '0'))
    .join()
    .toUpperCase();

/// The logo as a pure alpha mask, white where the mark is.
///
/// Handles both possible exports: blue-on-transparent (use the existing alpha)
/// and blue-on-white (no alpha, so derive coverage from how far each pixel is
/// from white). Recolouring to white lets the tile paint the mark knocked out
/// of a solid brand-blue background, which reads on a light or dark taskbar —
/// blue-on-transparent would disappear into one of them.
img.Image _asMask(img.Image src) {
  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  var anyAlpha = false;
  for (final p in src) {
    if (p.a < 250) {
      anyAlpha = true;
      break;
    }
  }
  for (var y = 0; y < src.height; y++) {
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      final int a;
      if (anyAlpha) {
        a = p.a.toInt();
      } else {
        // Distance from white, so the ink becomes opaque and paper becomes clear.
        final lum = (p.r * 0.299 + p.g * 0.587 + p.b * 0.114) / 255.0;
        a = ((1.0 - lum) * 255).round().clamp(0, 255);
      }
      out.setPixelRgba(x, y, 255, 255, 255, a);
    }
  }
  return out;
}

/// The logo's fill colour, taken as the most common fully-opaque pixel.
///
/// Deliberately the modal colour rather than the most saturated one: the most
/// saturated pixel in this logo is a dark antialiasing artifact on a letter
/// edge (#00539C), not the blue anyone would call the brand colour (#016EC9).
img.Color _dominantColour(img.Image src) {
  final counts = <int, int>{};
  for (final p in src) {
    if (p.a < 250) continue;
    final key = (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();
    counts[key] = (counts[key] ?? 0) + 1;
  }
  // A fully transparent or empty logo leaves nothing to sample; fall back to
  // the app's own primary blue rather than emitting a black tile.
  if (counts.isEmpty) return img.ColorRgb8(0x01, 0x6E, 0xC9);
  final modal = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  return img.ColorRgb8((modal >> 16) & 0xFF, (modal >> 8) & 0xFF, modal & 0xFF);
}

/// Crops the leading letter out of the wordmark by finding the first run of
/// non-empty columns. Letter spacing gives clean empty columns between glyphs,
/// so this needs no hardcoded coordinates and survives the logo being re-exported
/// at a different size.
img.Image _firstGlyph(img.Image mask) {
  bool columnHasInk(int x) {
    for (var y = 0; y < mask.height; y++) {
      if (mask.getPixel(x, y).a > 8) return true;
    }
    return false;
  }

  var start = 0;
  while (start < mask.width && !columnHasInk(start)) {
    start++;
  }
  var end = start;
  while (end < mask.width && columnHasInk(end)) {
    end++;
  }
  if (end <= start) return mask; // No gaps found — fall back to the whole mark.

  final glyph = img.copyCrop(mask, x: start, y: 0, width: end - start, height: mask.height);
  return _trimVertically(glyph);
}

/// Drops fully transparent rows so the glyph scales to fill its box.
img.Image _trimVertically(img.Image src) {
  int? top, bottom;
  for (var y = 0; y < src.height; y++) {
    var ink = false;
    for (var x = 0; x < src.width; x++) {
      if (src.getPixel(x, y).a > 8) {
        ink = true;
        break;
      }
    }
    if (ink) {
      top ??= y;
      bottom = y;
    }
  }
  if (top == null) return src;
  return img.copyCrop(src, x: 0, y: top, width: src.width, height: bottom! - top + 1);
}

/// Fills [canvas] edge to edge with [colour], rounding the corners to [radius].
///
/// Hand-rolled rather than img.fillRect(radius:) because that path is broken in
/// image 4.3.0: it sets `a = p.a * (1 - color.a * m)` using the raw 0-255 alpha
/// where it means the normalized one, so `1 - 255` goes negative and every
/// pixel clamps to fully transparent. The tile came out invisible at every size
/// that had a radius.
///
/// Corners are supersampled 4x4 so they read as curves rather than staircases
/// at 24-48px, which is where Windows actually shows this icon.
void _fillRoundedRect(img.Image canvas, img.Color colour, double radius) {
  final size = canvas.width;
  final r = colour.r.toInt(), g = colour.g.toInt(), b = colour.b.toInt();
  const samples = 4;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      var covered = 0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final px = x + (sx + 0.5) / samples;
          final py = y + (sy + 0.5) / samples;
          // Pull the sample back to the nearest point on the inner rectangle;
          // anything within `radius` of that is inside the rounded shape.
          final cx = px.clamp(radius, size - radius);
          final cy = py.clamp(radius, size - radius);
          final dx = px - cx, dy = py - cy;
          if (dx * dx + dy * dy <= radius * radius) covered++;
        }
      }
      final a = (255 * covered / (samples * samples)).round();
      canvas.setPixelRgba(x, y, r, g, b, a);
    }
  }
}

/// One icon frame: rounded brand-blue tile with [mark] knocked out in white,
/// scaled to fit inside the tile's padding without distorting its aspect ratio.
img.Image _tile(int size, img.Image mark, img.Color brand) {
  final canvas = img.Image(width: size, height: size, numChannels: 4);
  // Corner radius scales with the icon; below ~24px a rounded corner just reads
  // as a chewed edge, so the smallest frames stay square.
  final radius = size >= 24 ? size * 0.18 : 0.0;
  _fillRoundedRect(canvas, brand, radius);

  // Tighter padding on small frames — they need every pixel they can get.
  final pad = size <= 32 ? size * 0.14 : size * 0.18;
  final boxW = size - pad * 2;
  final boxH = size - pad * 2;
  final scale = math.min(boxW / mark.width, boxH / mark.height);
  final w = math.max(1, (mark.width * scale).round());
  final h = math.max(1, (mark.height * scale).round());

  final scaled = img.copyResize(mark,
      width: w, height: h, interpolation: img.Interpolation.cubic);
  img.compositeImage(canvas, scaled,
      dstX: ((size - w) / 2).round(), dstY: ((size - h) / 2).round());
  return canvas;
}
