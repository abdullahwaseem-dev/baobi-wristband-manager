/// Where an entry's dimensions came from. Drives the colour used to mark it in
/// the paper picker so staff can tell at a glance which document to check their
/// physical stock box against.
enum PaperSource {
  /// From the Baobi Configuration Reference. Only the four stocks the spec
  /// sheets don't mention at all are still on this.
  reference,

  /// From the vendor's two "Black Bar position" spec sheets (adhesive-closure
  /// and snap-closure). The authority wherever the two documents disagree.
  blackBarSheet,
}

/// All 35 BB720A wristband paper configurations — 34 from the vendor's two
/// "Black Bar position" sheets (adhesive-closure and snap-closure), plus the 1
/// Configuration Reference stock (BVP15480) neither sheet covers. BB720A is
/// the only printer this app supports — every entry is scoped to it, there is
/// no printer selector.
///
/// Not covered: BVP14300B-3, a 3-row band the single face/width model below
/// can't represent at all.
///
/// ## Where printing starts (the black bar)
///
/// Every one of these bands carries a printed black registration bar a fixed
/// distance in from the leading edge — 5mm on the adhesive-closure stock, 35mm
/// or 40mm on the snap-closure stock, past the snap tail. That bar is what the
/// BB720A's reflective sensor stops the media on, so **the first printable dot
/// lands immediately after the bar, not at the physical edge of the strip.**
///
/// [faceMm] is therefore measured from just past the bar to the end of the
/// printable panel, and [blackBarMm] is the labelled distance from the leading
/// edge to the bar itself. [stripMm] stays the full physical strip so the
/// numbers still reconcile against the spec sheet. Getting this wrong shifts
/// the whole band content down the strip, so face lengths are derived as
/// "panel length minus everything before the bar" rather than taken straight
/// off whichever dimension line is longest.
///
/// Every item number appears exactly once. Where the Configuration Reference
/// and a spec sheet described the same stock with materially different
/// dimensions, the reference entry was removed rather than kept alongside under
/// a disambiguating suffix — two rows with the same name and a 3x size
/// difference is worse for a ward clerk than one row that's simply right.
///
/// Face = printable face length (long axis) measured from just past the black bar,
/// Width = band width, FullStrip = total physical strip, LeadTab = run-up to the
/// black bar. All dimensions in mm.
class PaperConfig {
  final String itemNo;
  final String suffix;   // B = standard back, F = front/face, – = no suffix
  final double faceMm;   // printable face length (long axis), measured from past the black bar
  final double widthMm;  // wristband width (short axis)
  final double stripMm;  // full physical strip length
  final double leadTabMm;
  final int rotate;      // 0 = BVP landscape, 1 = portrait/label
  final PaperSource source;
  final double? panelMm; // printable panel height, when narrower than the band

  /// Per-stock replacement for [specSheetPrintOffsetMm], where a real test
  /// print measured a different distance-from-head for this specific stock.
  /// Null means "use the flat default" — see [printOffsetMm].
  final double? printOffsetOverrideMm;

  /// Distance from the page's TOP edge to where content should start,
  /// measured the same way every other dimension in this file is: a direct
  /// distance from a named edge, not a relative nudge. Null (the default)
  /// keeps content vertically centred on the page, as every stock printed
  /// before real per-stock measurements existed. At most one of
  /// [topInsetMm]/[bottomInsetMm] is ever set on a given entry.
  final double? topInsetMm;

  /// Same idea as [topInsetMm], measured from the page's BOTTOM edge instead.
  final double? bottomInsetMm;

  const PaperConfig({
    required this.itemNo,
    required this.suffix,
    required this.faceMm,
    required this.widthMm,
    required this.stripMm,
    required this.leadTabMm,
    this.rotate = 0,
    // Defaults to the sheets because all but one entry come from them now.
    // That one exception says so explicitly at the bottom of the table.
    this.source = PaperSource.blackBarSheet,
    this.panelMm,
    this.printOffsetOverrideMm,
    this.topInsetMm,
    this.bottomInsetMm,
  }) : assert(topInsetMm == null || bottomInsetMm == null,
            'set at most one of topInsetMm/bottomInsetMm — they measure from opposite edges');

  /// Height of the printable panel, short axis, in mm.
  ///
  /// On most stock this is the whole band, but the adhesive sheets draw an
  /// inner panel narrower than the band itself — e.g. BVP14380F is a 26mm band
  /// with a 19mm panel. Content is sized and centred against this, not against
  /// [widthMm], otherwise text laid out for the full band width spills past the
  /// panel edges. Defaults to [widthMm] where no inner panel is marked.
  double get printablePanelMm => panelMm ?? widthMm;

  /// The printable panel's rendered height after [topInsetMm]/[bottomInsetMm]
  /// eat into it, in mm.
  ///
  /// Shrinks the content box exactly the way [printOffsetMm] already shrinks
  /// the horizontal face (see print_service.dart's faceWidthMm) — a fixed
  /// page size never grows, so the content makes room for the inset instead.
  /// Font and QR sizing deliberately keep using [printablePanelMm] itself,
  /// not this — the physical printable window hasn't gotten smaller, it just
  /// needs the content positioned differently within the band's full width,
  /// so there's no reason to shrink text for a purely positional correction.
  double get effectivePanelMm => printablePanelMm - (topInsetMm ?? bottomInsetMm ?? 0.0);

  /// Distance from the leading edge of the strip to the black registration bar,
  /// i.e. the point printing starts from.
  ///
  /// Identical to [leadTabMm] on every entry, because the lead tab is exactly
  /// the run-up to the bar: on the spec sheets it's the dimension labelled
  /// "5 mm" / "35 mm" / "40 mm", and on the reference entries it's that
  /// document's own leading-tab figure for the same stretch of band. Exposed
  /// under its own name so call sites read as what they mean.
  double get blackBarMm => leadTabMm;

  /// True for the 31 entries taken from the vendor's "Black Bar position"
  /// sheets, which the paper picker marks in a separate colour.
  bool get isFromSpecSheet => source == PaperSource.blackBarSheet;

  /// Distance from the head (the black bar) to where content actually starts
  /// printing, in mm — a direct measurement, the same as [blackBarMm] itself,
  /// not a delta or a nudge.
  ///
  /// [specSheetPrintOffsetMm] (10mm) is the flat default for any spec-sheet
  /// stock nobody has test-printed individually yet. Several stocks HAVE
  /// been, on a real BB720A, and measured a different number — those set
  /// [printOffsetOverrideMm] and this getter returns that instead. The
  /// Configuration Reference stock prints correctly with none of this and
  /// stays at zero.
  static const double specSheetPrintOffsetMm = 10.0;

  double get printOffsetMm =>
      printOffsetOverrideMm ?? (isFromSpecSheet ? specSheetPrintOffsetMm : 0.0);

  /// Human-readable display name for the dropdown
  String get displayName => '$itemNo  (${faceMm.toStringAsFixed(0)}×${widthMm.toStringAsFixed(0)} mm)';

  /// Short label for UI chips
  String get shortLabel => '${faceMm.toStringAsFixed(0)}×${widthMm.toStringAsFixed(0)}mm';

  /// Every stock the two "Black Bar position" sheets specify, one entry per item
  /// number actually printed on them, followed by the few Configuration
  /// Reference stocks those sheets don't cover at all.
  ///
  /// The sheets group several SKUs onto a single drawing (e.g. "BVP14340F /
  /// BVP14340B / BVP15340" share one set of dimensions). Each gets its own row
  /// here rather than one row per drawing, because staff match by the number
  /// printed on the box in front of them and shouldn't have to know which
  /// grouping theirs falls under.
  ///
  /// Reference entries for anything the sheets DO cover have been removed. They
  /// disagreed with the sheets by a factor of ~3 on several stocks, and keeping
  /// both meant two rows with the same item number and different sizes — the
  /// sheet is the authority, so it wins outright.
  ///
  /// Not covered: BVP14300B-3, a 3-row band the single face/width model above
  /// can't represent at all.
  static const List<PaperConfig> all = [
    // ══ Adhesive closure sheet, page 1 ══════════════════════════════════════
    // Bar sits 5mm in. The sheet marks the full strip, the after-bar face, the
    // band width, and an inner printable panel narrower than the band.

    // 295 strip / 285 face / 26 band / 19 panel
    PaperConfig(itemNo: 'BB720_BVP14340F', suffix: 'F', faceMm: 285.0, widthMm: 26.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 19.0),
    PaperConfig(itemNo: 'BB720_BVP14340B', suffix: 'B', faceMm: 285.0, widthMm: 26.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 19.0),
    PaperConfig(itemNo: 'BB720_BVP15340',  suffix: '-', faceMm: 285.0, widthMm: 26.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 19.0),
    // 295 strip / 285 face / 36 band / 29 panel
    // Second round of real BB720A test prints (Wristband Position Deviation
    // PDF) measured BVP14350B and BVP14250B diverging from each other, even
    // though they'd shared one correction since the first round — each now
    // carries its own head offset and top inset rather than a shared value.
    // "Shifts N mm toward the head end" is an instruction to move content
    // TOWARD the head — i.e. REDUCE the head offset, not add to it (the
    // opposite reading was tried first and shipped in the wrong direction —
    // see paper_config_test.dart for the reasoning this correction is built on).
    PaperConfig(itemNo: 'BB720_BVP14350F', suffix: 'F', faceMm: 285.0, widthMm: 36.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 29.0, printOffsetOverrideMm: 3.0, topInsetMm: 1.5),
    PaperConfig(itemNo: 'BB720_BVP14350B', suffix: 'B', faceMm: 285.0, widthMm: 36.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 29.0, printOffsetOverrideMm: 3.0, topInsetMm: 1.5),
    PaperConfig(itemNo: 'BB720_BVP15350',  suffix: '-', faceMm: 285.0, widthMm: 36.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 29.0, printOffsetOverrideMm: 3.0, topInsetMm: 1.5),
    PaperConfig(itemNo: 'BB720_BVP14250B', suffix: 'B', faceMm: 285.0, widthMm: 36.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 29.0, printOffsetOverrideMm: 3.0, topInsetMm: 1.0),
    // 269 strip / 260 face / 32 band / 25 panel
    // Second round confirmed the same 1mm top inset as before, plus a head
    // offset this stock hadn't had measured until now.
    PaperConfig(itemNo: 'BB720_BVP14360F', suffix: 'F', faceMm: 260.0, widthMm: 32.0, stripMm: 269.0, leadTabMm: 5.0, panelMm: 25.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    PaperConfig(itemNo: 'BB720_BVP14360B', suffix: 'B', faceMm: 260.0, widthMm: 32.0, stripMm: 269.0, leadTabMm: 5.0, panelMm: 25.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    PaperConfig(itemNo: 'BB720_BVP15360',  suffix: '-', faceMm: 260.0, widthMm: 32.0, stripMm: 269.0, leadTabMm: 5.0, panelMm: 25.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    // 190 strip / 180 face / 26 band / 19 panel
    // Head offset and top inset both newly measured this round; the inset is
    // inferred from BVP14360's identical "shift down 1mm" instruction on the
    // same adhesive sheet rather than photographed directly for this stock —
    // worth one confirmation print since it's inferred, not measured.
    PaperConfig(itemNo: 'BB720_BVP14380F', suffix: 'F', faceMm: 180.0, widthMm: 26.0, stripMm: 190.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    PaperConfig(itemNo: 'BB720_BVP14380B', suffix: 'B', faceMm: 180.0, widthMm: 26.0, stripMm: 190.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    PaperConfig(itemNo: 'BB720_BVP15380',  suffix: '-', faceMm: 180.0, widthMm: 26.0, stripMm: 190.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    // 231 strip / 222 face / 26 band / 19 panel
    // Head offset newly measured; no vertical correction reported for this one.
    PaperConfig(itemNo: 'BB720_BVP14390F', suffix: 'F', faceMm: 222.0, widthMm: 26.0, stripMm: 231.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0),
    PaperConfig(itemNo: 'BB720_BVP14390B', suffix: 'B', faceMm: 222.0, widthMm: 26.0, stripMm: 231.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0),
    PaperConfig(itemNo: 'BB720_BVP15390',  suffix: '-', faceMm: 222.0, widthMm: 26.0, stripMm: 231.0, leadTabMm: 5.0, panelMm: 19.0, printOffsetOverrideMm: 5.0),

    // ══ Adhesive closure sheet, page 2 ══════════════════════════════════════
    // "-DS" = double sided: same band as its single-sided sibling above, just
    // printable on both faces, so the dimensions match.
    // Not individually named in the vendor's QA photos, but this is the exact
    // same panel geometry as the single-sided BVP14350F/BVP14360F above —
    // same physical printable window, so the same top-inset correction should
    // apply. Worth one confirmation print since it's inferred, not measured.
    PaperConfig(itemNo: 'BB720_BVP14350F-DS', suffix: 'F', faceMm: 285.0, widthMm: 36.0, stripMm: 295.0, leadTabMm: 5.0, panelMm: 29.0, printOffsetOverrideMm: 3.0, topInsetMm: 1.5),
    PaperConfig(itemNo: 'BB720_BVP14360F-DS', suffix: 'F', faceMm: 260.0, widthMm: 32.0, stripMm: 269.0, leadTabMm: 5.0, panelMm: 25.0, printOffsetOverrideMm: 5.0, topInsetMm: 1.0),
    // 292 strip, no after-bar face marked (taken as strip − bar) and no inner
    // panel drawn, so this one uses the full band width.
    PaperConfig(itemNo: 'BB720_BVP12340-DS', suffix: '-', faceMm: 287.0, widthMm: 30.0, stripMm: 292.0, leadTabMm: 5.0),

    // ══ Snap closure sheet, page 1 ══════════════════════════════════════════
    // 40mm snap tail up to the bar, then the rest of the strip is printable, so
    // face = strip − tail. No inner panel drawn on any of these.
    //
    // A second round of real BB720A test prints (Wristband Position Deviation
    // PDF) re-measured every stock below. "Content shifts N mm toward the
    // head end" is an instruction — move content TOWARD the head, i.e.
    // REDUCE the head offset by N mm, not add N mm to it. For every stock in
    // this group the first round's offset (20-30mm) is smaller than the
    // reported shift (36-55mm), so the corrected offset floors out at exactly
    // 0mm — printing starts immediately at the sensor's stop point, no extra
    // buffer at all. That floor lines up exactly with this same batch's
    // separately-reported "stop position overhangs by Nmm" measurements for
    // these same stocks: even at zero software offset, the PHYSICAL stop
    // point itself still overhangs too far toward the tail. Closing that
    // remaining gap is a printer black-mark-sensing/media-length calibration
    // matter, not something this offset can reach — see PaperConfig's class
    // doc and flag it to Baobi support/hardware, not paper_config.dart.
    PaperConfig(itemNo: 'BB720_BVP14400B', suffix: 'B', faceMm: 255.0, widthMm: 29.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, topInsetMm: 1.0),
    // Head offset floors at 0 same as its groupmates; top inset carried over
    // from the first round since no vertical correction was reported this time.
    PaperConfig(itemNo: 'BB720_BVP14200B', suffix: 'B', faceMm: 255.0, widthMm: 29.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, topInsetMm: 1.5),
    // Face side of the same physical band as BVP14400B (see the
    // "Configuration Reference only" note lower down) — kept identical per
    // the geometry-match test, since no independent BVP14400F measurement
    // exists this round either.
    PaperConfig(itemNo: 'BB720_BVP14400F', suffix: 'F', faceMm: 255.0, widthMm: 29.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, topInsetMm: 1.0),
    PaperConfig(itemNo: 'BB720_BVP14410B', suffix: 'B', faceMm: 255.0, widthMm: 25.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 2.0),
    PaperConfig(itemNo: 'BB720_BVP14210B', suffix: 'B', faceMm: 255.0, widthMm: 25.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 2.0),
    // Face side of the same physical band as BVP14410B — kept identical per
    // the geometry-match test, no independent BVP14410F measurement this round.
    PaperConfig(itemNo: 'BB720_BVP14410F', suffix: 'F', faceMm: 255.0, widthMm: 25.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 2.0),
    // The sheet prints "BVP14410B" over both row 2 and row 3. Row 3's real SKU
    // is its partner BVP14220B — there is no second BVP14410B.
    // No vertical correction reported for BVP14430B this round — bottom inset
    // stays at the first round's 1.5mm while its former groupmates above move
    // to 2.0mm. Its head offset also floors at 0, just like the rest of this
    // group. BVP14430B also has a separate reported issue (one print job
    // producing two physical pieces, the second blank) that is NOT a position
    // problem and isn't addressed by this offset — see print_service.dart.
    PaperConfig(itemNo: 'BB720_BVP14430B', suffix: 'B', faceMm: 239.0, widthMm: 25.0, stripMm: 279.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 1.5),
    PaperConfig(itemNo: 'BB720_BVP14460B', suffix: 'B', faceMm: 214.0, widthMm: 25.0, stripMm: 254.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 2.0),
    PaperConfig(itemNo: 'BB720_BVP14220B', suffix: 'B', faceMm: 255.0, widthMm: 19.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 7.5),
    // Face side of the same physical band as BVP14220B (matched by numeric
    // root — BVP14220 pairs B/F the same way BVP14400 and BVP14410 do). Both
    // floor at the same 0mm head offset, but this round's real per-face
    // measurements show the vertical inset now needs its OWN, slightly
    // different value rather than matching BVP14220B exactly — see the
    // relaxed geometry-match test in paper_config_test.dart for why.
    PaperConfig(itemNo: 'BB720_BVP14420F', suffix: 'F', faceMm: 255.0, widthMm: 19.0, stripMm: 295.0, leadTabMm: 40.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 6.0),

    // ══ Snap closure sheet, page 2 ══════════════════════════════════════════
    // These three are 254mm strips whose dimension lines partition the strip
    // from the SAME leading edge: 14470B reads 203 + 51 = 254, with the 35mm
    // snap tail measured from that same edge and therefore sitting INSIDE the
    // 203mm. Printable panel is 203 − 35 = 168mm; taking the longer dimension
    // at face value would push the band 35mm down the strip.
    PaperConfig(itemNo: 'BB720_BVP14470B', suffix: 'B', faceMm: 168.0, widthMm: 19.0, stripMm: 254.0, leadTabMm: 35.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 7.0), // 203 − 35
    PaperConfig(itemNo: 'BB720_BVP14480B', suffix: 'B', faceMm: 145.0, widthMm: 19.0, stripMm: 254.0, leadTabMm: 35.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 7.0), // 180 − 35
    PaperConfig(itemNo: 'BB720_BVP14490B', suffix: 'B', faceMm: 187.0, widthMm: 19.0, stripMm: 254.0, leadTabMm: 35.0, printOffsetOverrideMm: 0.0, bottomInsetMm: 7.0), // 222 − 35
    PaperConfig(itemNo: 'BB720_BVP14210F', suffix: 'F', faceMm: 220.0, widthMm: 26.0, stripMm: 260.0, leadTabMm: 40.0),
    // BVP14200F: unchanged from the first round (head 20mm, 1.5mm from the top
    // edge) — no independent second-round measurement for this one, and unlike
    // BVP14400F it isn't confirmed to be the same physical band as anything
    // above (separate drawing on the sheet — see the vendor's QA photos, which
    // group by shared offset need, not by shared geometry), so it's left as-is
    // rather than guessed at.
    PaperConfig(itemNo: 'BB720_BVP14200F', suffix: 'F', faceMm: 217.0, widthMm: 29.0, stripMm: 257.0, leadTabMm: 40.0, printOffsetOverrideMm: 20.0, topInsetMm: 1.5),

    // ══ Configuration Reference only ════════════════════════════════════════
    // BVP15480 is the only item number neither sheet mentions at all — it
    // keeps the Reference's own dimensions, stays blue in the picker, and
    // takes no print offset.
    //
    // BVP14400F/14410F/14420F used to be here too, on the Reference's
    // ~110mm-face dimensions. Real test prints confirmed they're actually the
    // front/face side of the SAME physical band as BVP14400B/14410B/14220B
    // respectively (matched by numeric root, e.g. 14400F/14400B), not a
    // separate stock — so they've moved up to the snap-closure group above
    // with their sibling's real geometry, plus that sibling's offset
    // correction on top.
    PaperConfig(itemNo: 'BB720_BVP15480',  suffix: '-', faceMm:  71.0, widthMm: 16.0, stripMm:  97.2, leadTabMm: 21.5, source: PaperSource.reference),
  ];

  static PaperConfig byItemNo(String itemNo) =>
      all.firstWhere((p) => p.itemNo == itemNo, orElse: () => all.first);

  /// Pinned by item number rather than list position, so reordering the table
  /// above can't silently change what a station that never picked a stock ends
  /// up printing on. Matches SettingsService.selectedPaperItemNo's own default.
  static PaperConfig get defaultConfig => byItemNo('BB720_BVP14200B');
}
