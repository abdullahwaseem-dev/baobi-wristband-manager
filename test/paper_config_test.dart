import 'package:flutter_test/flutter_test.dart';
import 'package:baobi_wristband/models/paper_config.dart';

/// Guards the paper table's invariants: one row per item number, the spec
/// sheets winning over the Configuration Reference wherever both describe a
/// stock, and the geometry that's easy to silently get wrong.
void main() {
  test('every item number is unique', () {
    // byItemNo() resolves with firstWhere, so a duplicate key would silently
    // shadow the second entry and it would become unselectable. This is also
    // the whole point of dropping the reference rows that clashed with the
    // sheets — a name must mean exactly one set of dimensions.
    final seen = PaperConfig.all.map((p) => p.itemNo).toSet();
    expect(seen.length, PaperConfig.all.length);
  });

  test('only the one stock absent from both sheets stays on the reference', () {
    // BVP14400F/14410F/14420F used to be here too, on ~110mm reference
    // dimensions, until real test prints confirmed they're the face side of
    // the SAME physical band as BVP14400B/14410B/14220B — see the geometry
    // test below.
    const referenceOnly = {'BB720_BVP15480'};
    for (final p in PaperConfig.all) {
      expect(p.isFromSpecSheet, !referenceOnly.contains(p.itemNo),
          reason: '${p.itemNo} is attributed to the wrong document');
    }
    expect(PaperConfig.all.length, 35);
  });

  test('BVP14400F/14410F/14420F match their B-sibling\'s physical geometry exactly', () {
    // Confirmed by a real BB720A test print, not inferred — see
    // paper_config.dart's "Configuration Reference only" section. This checks
    // physical dimensions only (face/width/strip/black bar) — those haven't
    // changed. The measured print CORRECTION (offset/inset) is checked
    // separately below, since a second round of real per-face test prints
    // found BVP14420F and BVP14220B now need different corrections despite
    // sharing the same physical band.
    for (final pair in [
      ('BB720_BVP14400F', 'BB720_BVP14400B'),
      ('BB720_BVP14410F', 'BB720_BVP14410B'),
      ('BB720_BVP14420F', 'BB720_BVP14220B'), // paired by numeric root, not by matching name
    ]) {
      final f = PaperConfig.byItemNo(pair.$1);
      final b = PaperConfig.byItemNo(pair.$2);
      expect(f.itemNo, pair.$1, reason: '${pair.$1} is missing from the table');
      expect(f.faceMm, b.faceMm, reason: '${pair.$1} face should match ${pair.$2}');
      expect(f.widthMm, b.widthMm, reason: '${pair.$1} width should match ${pair.$2}');
      expect(f.stripMm, b.stripMm, reason: '${pair.$1} strip should match ${pair.$2}');
      expect(f.blackBarMm, b.blackBarMm, reason: '${pair.$1} black bar should match ${pair.$2}');
    }
  });

  test('BVP14400F/14410F/14420F share their B-sibling\'s head offset, but BVP14420F has its own vertical inset', () {
    // All four of this round's re-measured snap-closure head offsets floor
    // at 0mm (see the print-offset test above), so BVP14420F and BVP14220B
    // happen to match again on THAT axis even though the real per-face test
    // prints found them diverging on the vertical inset.
    for (final pair in [
      ('BB720_BVP14400F', 'BB720_BVP14400B'),
      ('BB720_BVP14410F', 'BB720_BVP14410B'),
      ('BB720_BVP14420F', 'BB720_BVP14220B'),
    ]) {
      final f = PaperConfig.byItemNo(pair.$1);
      final b = PaperConfig.byItemNo(pair.$2);
      expect(f.printOffsetMm, b.printOffsetMm, reason: '${pair.$1} print offset should match ${pair.$2}');
    }
    final f420 = PaperConfig.byItemNo('BB720_BVP14420F');
    final b220 = PaperConfig.byItemNo('BB720_BVP14220B');
    expect(f420.bottomInsetMm, 6.0);
    expect(b220.bottomInsetMm, 7.5);
  });

  test('no disambiguating suffixes survive', () {
    // Entries used to be suffixed with their strip length (e.g. _295) to coexist
    // with a clashing reference row. Those rows are gone, so the suffixes should
    // be too — a leftover would mean a clash was resolved by hiding it.
    for (final p in PaperConfig.all) {
      expect(RegExp(r'_\d+$').hasMatch(p.itemNo), isFalse,
          reason: '${p.itemNo} still carries a disambiguating suffix');
    }
  });

  test('spec-sheet stocks carry the flat print offset unless a real test print overrode it', () {
    for (final p in PaperConfig.all) {
      final expected = p.printOffsetOverrideMm ?? (p.isFromSpecSheet ? PaperConfig.specSheetPrintOffsetMm : 0.0);
      expect(p.printOffsetMm, expected, reason: '${p.itemNo} has the wrong print offset for its source');
    }
  });

  test('per-stock print-offset overrides measured off real BB720A test prints', () {
    // See paper_config.dart's snap-closure section — these replace the flat
    // 10mm default outright, they don't add to it. Second-round values (from
    // the Wristband Position Deviation PDF) SUBTRACT from the first round's
    // already-shipped number: "content shifts N mm toward the head end" is an
    // instruction to move content toward the head, i.e. reduce the offset,
    // not increase it — confirmed against a real physical test print after an
    // earlier attempt applied this in the opposite (additive) direction and
    // shipped it backwards. Every snap-closure stock below floors at exactly
    // 0mm since the requested leftward shift exceeds what the first round's
    // offset had room to give; that floor matches this same PDF's separately-
    // reported "stop position overhangs" data for the same stocks almost
    // one-for-one, which is real, but a printer hardware/calibration matter,
    // not something this offset can reach — see paper_config.dart.
    const expected = {
      // Snap closure, first round unchanged (no second-round data for this one):
      'BB720_BVP14200F': 20.0,
      // Snap closure, re-measured in round two — every one floors at 0mm:
      'BB720_BVP14400B': 0.0, 'BB720_BVP14200B': 0.0, 'BB720_BVP14400F': 0.0,
      'BB720_BVP14410B': 0.0, 'BB720_BVP14210B': 0.0, 'BB720_BVP14410F': 0.0,
      'BB720_BVP14430B': 0.0, 'BB720_BVP14460B': 0.0,
      'BB720_BVP14220B': 0.0, 'BB720_BVP14420F': 0.0,
      'BB720_BVP14470B': 0.0, 'BB720_BVP14480B': 0.0, 'BB720_BVP14490B': 0.0,
      // Adhesive closure, newly measured in round two (previously the flat 10mm default):
      'BB720_BVP14350F': 3.0, 'BB720_BVP14350B': 3.0, 'BB720_BVP15350': 3.0, 'BB720_BVP14350F-DS': 3.0,
      'BB720_BVP14250B': 3.0,
      'BB720_BVP14360F': 5.0, 'BB720_BVP14360B': 5.0, 'BB720_BVP15360': 5.0, 'BB720_BVP14360F-DS': 5.0,
      'BB720_BVP14380F': 5.0, 'BB720_BVP14380B': 5.0, 'BB720_BVP15380': 5.0,
      'BB720_BVP14390F': 5.0, 'BB720_BVP14390B': 5.0, 'BB720_BVP15390': 5.0,
    };
    for (final entry in expected.entries) {
      final p = PaperConfig.byItemNo(entry.key);
      expect(p.itemNo, entry.key, reason: '${entry.key} is missing from the table');
      expect(p.printOffsetMm, entry.value, reason: '${entry.key}: wrong measured head offset');
    }
  });

  test('per-stock top/bottom insets measured off real BB720A test prints', () {
    // Second-round values (Wristband Position Deviation PDF) are TOTAL
    // replacement values, unlike the head offsets above — see paper_config.dart.
    const expectedTop = {
      'BB720_BVP14400B': 1.0, 'BB720_BVP14400F': 1.0,
      'BB720_BVP14200B': 1.5, 'BB720_BVP14200F': 1.5, // unchanged, no second-round data
      'BB720_BVP14350F': 1.5, 'BB720_BVP14350B': 1.5, 'BB720_BVP15350': 1.5, 'BB720_BVP14350F-DS': 1.5,
      'BB720_BVP14250B': 1.0, // diverged from the BVP14350 group this round
      'BB720_BVP14360F': 1.0, 'BB720_BVP14360B': 1.0, 'BB720_BVP15360': 1.0, 'BB720_BVP14360F-DS': 1.0,
      'BB720_BVP14380F': 1.0, 'BB720_BVP14380B': 1.0, 'BB720_BVP15380': 1.0, // newly measured
    };
    const expectedBottom = {
      'BB720_BVP14410B': 2.0, 'BB720_BVP14210B': 2.0, 'BB720_BVP14410F': 2.0,
      'BB720_BVP14460B': 2.0,
      'BB720_BVP14430B': 1.5, // unchanged, no second-round data — diverged from the group above
      'BB720_BVP14220B': 7.5,
      'BB720_BVP14420F': 6.0, // diverged from BVP14220B this round
      'BB720_BVP14470B': 7.0, 'BB720_BVP14480B': 7.0, 'BB720_BVP14490B': 7.0,
    };
    for (final entry in expectedTop.entries) {
      final p = PaperConfig.byItemNo(entry.key);
      expect(p.itemNo, entry.key, reason: '${entry.key} is missing from the table');
      expect(p.topInsetMm, entry.value, reason: '${entry.key}: wrong measured top inset');
      expect(p.bottomInsetMm, isNull, reason: '${entry.key}: should only carry a top inset');
    }
    for (final entry in expectedBottom.entries) {
      final p = PaperConfig.byItemNo(entry.key);
      expect(p.itemNo, entry.key, reason: '${entry.key} is missing from the table');
      expect(p.bottomInsetMm, entry.value, reason: '${entry.key}: wrong measured bottom inset');
      expect(p.topInsetMm, isNull, reason: '${entry.key}: should only carry a bottom inset');
    }
    // Everything else keeps the original default: perfectly centred, exactly
    // as every stock printed before per-stock vertical measurements existed.
    final corrected = {...expectedTop.keys, ...expectedBottom.keys};
    for (final p in PaperConfig.all) {
      if (corrected.contains(p.itemNo)) continue;
      expect(p.topInsetMm, isNull, reason: '${p.itemNo}: unexpected top inset');
      expect(p.bottomInsetMm, isNull, reason: '${p.itemNo}: unexpected bottom inset');
    }
  });

  test('a vertical inset never eats the whole printable panel', () {
    for (final p in PaperConfig.all) {
      expect(p.effectivePanelMm, greaterThan(p.printablePanelMm * 0.5),
          reason: '${p.itemNo}: top/bottom inset takes too much of the panel');
    }
  });

  test('the offset never eats more than the printable face allows', () {
    // The offset comes out of the face width, so a short stock plus a large
    // offset could in principle leave nothing to print on. Second-round
    // corrections (subtracting toward the head, not adding toward the tail —
    // see the print-offset test above) brought every offset down to 0-5mm, so
    // the threshold is back to its original, tighter value.
    for (final p in PaperConfig.all) {
      expect(p.faceMm - p.printOffsetMm, greaterThan(p.faceMm * 0.5),
          reason: '${p.itemNo}: offset takes too much of the face');
      expect(p.faceMm - p.printOffsetMm, greaterThan(50.0),
          reason: '${p.itemNo}: offset leaves less than 50mm of face — too little to print a wristband on');
    }
  });

  test('the panel is never wider than the band it sits on', () {
    for (final p in PaperConfig.all) {
      expect(p.printablePanelMm, lessThanOrEqualTo(p.widthMm),
          reason: '${p.itemNo}: panel is wider than the band');
    }
  });

  group('adhesive stocks size against the inner panel, not the band', () {
    // The adhesive sheet draws a printable panel narrower than the band on
    // every group. Sizing text off the band overflowed it by ~2mm.
    // Not const: doubles override ==, so they can't key a constant map.
    final panelForBand = {36.0: 29.0, 32.0: 25.0, 26.0: 19.0};

    for (final entry in panelForBand.entries) {
      test('${entry.key.toInt()}mm band -> ${entry.value.toInt()}mm panel', () {
        final matching = PaperConfig.all.where(
            (p) => p.blackBarMm == 5.0 && p.widthMm == entry.key && p.itemNo != 'BB720_BVP12340-DS');
        expect(matching, isNotEmpty);
        for (final p in matching) {
          expect(p.printablePanelMm, entry.value, reason: p.itemNo);
        }
      });
    }
  });

  group('snap-closure stocks exclude their own tail from the face', () {
    // On page 2 of the snap sheet the 254mm strip is partitioned from the same
    // leading edge as the 35mm snap tail (e.g. 203 + 51 = 254), so the tail
    // sits INSIDE the larger figure. Taking that figure as the face pushed
    // every band 35mm down the strip. Panel lengths from the sheet:
    const panelMm = {
      'BB720_BVP14470B': 203.0,
      'BB720_BVP14480B': 180.0,
      'BB720_BVP14490B': 222.0,
    };

    for (final entry in panelMm.entries) {
      test(entry.key, () {
        final p = PaperConfig.byItemNo(entry.key);
        expect(p.itemNo, entry.key, reason: 'entry went missing from the table');
        expect(p.faceMm, entry.value - p.blackBarMm);
      });
    }
  });

  test('snap sheet rows 1-3 all share the 295mm strip and 40mm tail', () {
    for (final id in [
      'BB720_BVP14400B', 'BB720_BVP14200B',
      'BB720_BVP14410B', 'BB720_BVP14210B',
      'BB720_BVP14220B',
    ]) {
      final p = PaperConfig.byItemNo(id);
      expect(p.itemNo, id, reason: '$id is missing from the table');
      expect(p.faceMm, 255.0);
      expect(p.stripMm, 295.0);
      expect(p.blackBarMm, 40.0);
    }
  });

  test('the default stock is pinned by name, not by list position', () {
    // SettingsService falls back to this same string, so a reorder that changed
    // the default would silently change what an unconfigured station prints on.
    expect(PaperConfig.defaultConfig.itemNo, 'BB720_BVP14200B');
  });
}
