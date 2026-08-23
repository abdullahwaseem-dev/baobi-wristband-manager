import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/patient.dart';
import '../models/paper_config.dart';
import 'settings_service.dart';

class PrintService {
  PrintService._();
  static final PrintService instance = PrintService._();

  // The default PDF base fonts (Helvetica etc.) have no CJK glyphs, so
  // Chinese text silently prints as nothing. This CJK font is registered as
  // a fallback on the document theme — Latin text still uses the default
  // font, and any character missing from it (Chinese, in practice) falls
  // through to this one automatically. Loaded once and cached; ~17MB, so we
  // don't want to re-read it from the asset bundle on every print job.
  pw.Font? _cjkFont;

  Future<pw.Font> _loadCjkFont() async {
    final cached = _cjkFont;
    if (cached != null) return cached;
    final data = await rootBundle.load('assets/fonts/NotoSansCJKsc-Regular.ttf');
    final font = pw.Font.ttf(data);
    _cjkFont = font;
    return font;
  }

  /// Print wristband for [patient] using the currently selected paper config.
  ///
  /// All platforms use a LANDSCAPE PDF:
  ///   faceMm (110mm) = page width (long axis, left-right when worn)
  ///   widthMm (29mm) = page height (short axis, band width)
  ///
  /// The landscape [format] is passed explicitly to the print job so the
  /// BB720A Windows driver uses landscape orientation and does not clip content.
  ///
  /// Print always begins immediately after the band's black registration bar,
  /// never at the physical edge of the strip — see [PaperConfig] for the
  /// geometry. The two platforms get there differently:
  ///
  /// Windows: face-only landscape page (faceMm × widthMm), zero offset. The
  ///   BB720A's reflective sensor halts the media on the bar, so the top of the
  ///   page already IS the first printable dot past it; adding an offset here
  ///   would double-count the run-up the printer has physically fed.
  /// macOS / Linux (CUPS): no black-mark stop, so the full strip
  ///   (stripMm × widthMm) is laid out and the face content is pushed
  ///   horizontally by blackBarMm to land in the same place.
  Future<bool> printWristband(Patient patient) async {
    try {
      final settings = SettingsService.instance;
      final paper = PaperConfig.byItemNo(settings.selectedPaperItemNo);

      final pdfBytes = await _buildWristbandPdf(patient, paper);

      // Landscape format for this paper — passed explicitly so the driver
      // configures the job in landscape and does not clip the 110mm wide page.
      final landscapeFormat = PdfPageFormat(
        paper.faceMm  * PdfPageFormat.mm,  // 110mm — long axis
        paper.widthMm * PdfPageFormat.mm,  // 29mm  — band width
      );

      if (Platform.isWindows) {
        final printerName = settings.printerName;
        if (printerName.isNotEmpty) {
          final printers = await Printing.listPrinters();
          final target = printers.where((p) =>
              p.name.toLowerCase().contains('baobi') ||
              p.name.toLowerCase().contains('bb720') ||
              p.name == printerName).firstOrNull;
          if (target != null) {
            return await Printing.directPrintPdf(
              printer: target,
              onLayout: (_) async => pdfBytes,
              name: 'Wristband_${patient.patientId}',
              format: landscapeFormat,
            );
          }
        }
      }

      // macOS / Linux (CUPS) / Android / Windows fallback — native print dialog
      return await Printing.layoutPdf(
        onLayout: (_) async => pdfBytes,
        name: 'Wristband_${patient.patientId}',
        format: landscapeFormat,
      );
    } catch (e) {
      debugPrint('PrintService error: $e');
      return false;
    }
  }

  /// Build the landscape wristband PDF.
  Future<Uint8List> _buildWristbandPdf(Patient patient, PaperConfig paper) async {
    final cjkFont = await _loadCjkFont();
    final doc = pw.Document(theme: pw.ThemeData.withFont(fontFallback: [cjkFont]));
    final isWindows = Platform.isWindows;

    // Landscape orientation:
    //   page width  = faceMm (110mm) — long axis, horizontal when worn
    //   page height = widthMm (29mm) — band width, short axis
    // Both paths put the first printable dot immediately past the black bar.
    // Windows: the sensor already stopped the media there, so the page starts
    // at the bar and needs no offset. CUPS: lay out the whole strip and shift
    // the face in by the bar's distance from the leading edge.
    //
    // printOffsetMm is then added on top of either — the measured trim that
    // nudges spec-sheet stocks further along the strip. It comes out of the
    // face's own width rather than lengthening the page, so the content can
    // never be pushed off the end of the printable panel.
    final double pageWidthMm  = isWindows ? paper.faceMm : paper.stripMm;
    final double pageHeightMm = paper.widthMm;
    final double faceOffsetMm = (isWindows ? 0 : paper.blackBarMm) + paper.printOffsetMm;
    final double faceWidthMm  = paper.faceMm - paper.printOffsetMm;

    final pageFormat = PdfPageFormat(
      pageWidthMm  * PdfPageFormat.mm,
      pageHeightMm * PdfPageFormat.mm,
    );

    doc.addPage(pw.Page(
      pageFormat: pageFormat,
      margin: pw.EdgeInsets.zero,
      build: (ctx) {
        final faceContent = _buildFaceContent(patient, paper, faceWidthMm: faceWidthMm);
        // Full-strip: horizontal blank (leading tab) before the face area.
        final body = faceOffsetMm == 0
            ? faceContent
            : pw.Row(children: [
                pw.SizedBox(width: faceOffsetMm * PdfPageFormat.mm),
                faceContent,
              ]);
        return _verticalPosition(paper, body, pageHeightMm);
      },
    ));

    return doc.save();
  }

  /// Positions [body] (height [paper].effectivePanelMm) vertically within a
  /// [pageHeightMm]-tall page.
  ///
  /// Deliberately always a TOP padding, computed to land wherever is actually
  /// wanted, rather than switching between top/bottom-side Padding depending
  /// on which inset is set. Verified directly (see the isolated layout probe
  /// this was built from) that plain `pw.Padding(only: bottom:)` does NOT
  /// anchor its child to the bottom edge — with no Center/Align/Expand
  /// wrapping it, a pw.Page's build result renders at its own top-left by
  /// default, so bottom padding just adds trailing dead space below content
  /// that still sits flush at the top, silently applying no correction at
  /// all. Top padding doesn't have this problem — content's own top-left
  /// default anchor means "N mm of top padding" already places its top edge
  /// exactly N mm down — so bottom-inset stocks are handled by computing the
  /// equivalent top padding instead of trusting Padding's bottom side.
  pw.Widget _verticalPosition(PaperConfig paper, pw.Widget body, double pageHeightMm) {
    final bodyHeightMm = paper.effectivePanelMm;
    final double topPaddingMm;
    if (paper.topInsetMm != null) {
      topPaddingMm = paper.topInsetMm!;
    } else if (paper.bottomInsetMm != null) {
      topPaddingMm = pageHeightMm - bodyHeightMm - paper.bottomInsetMm!;
    } else {
      // Centred — matches pw.Center exactly (verified against the same
      // probe), kept as plain arithmetic so this is the ONE code path
      // handling all three cases instead of a separate Center branch.
      topPaddingMm = (pageHeightMm - bodyHeightMm) / 2;
    }
    return pw.Padding(
      padding: pw.EdgeInsets.only(top: topPaddingMm * PdfPageFormat.mm),
      child: body,
    );
  }

  /// Landscape face content: faceMm × widthMm (e.g. 110mm × 29mm).
  /// Left column = patient info; right = QR code.
  ///
  /// [faceWidthMm] overrides the full face length when a print offset has
  /// eaten into it, so the content lays itself out inside what's actually left
  /// of the panel instead of being sized for space it no longer has.
  pw.Widget _buildFaceContent(Patient patient, PaperConfig paper, {double? faceWidthMm}) {
    final hasAllergy = patient.allergy.isNotEmpty &&
        patient.allergy.toLowerCase() != 'none';
    final genderLabel =
        patient.gender == 'Female' ? 'F' : (patient.gender.isNotEmpty ? 'M' : '');
    // QR square fits inside the printable panel with small margin
    final double qrMm = paper.printablePanelMm * 0.58;

    return pw.Container(
      width:  (faceWidthMm ?? paper.faceMm) * PdfPageFormat.mm,  // 110mm
      // Panel, not band: on stock with a narrower inner panel this box is
      // shorter than the page and gets positioned within it by
      // _verticalPosition (centred by default, or per-stock top/bottom inset)
      // — either way content stays inside the panel rather than spreading
      // edge to edge. effectivePanelMm, not printablePanelMm: shrinks to make
      // room for a top/bottom inset the same way faceWidthMm already shrinks
      // for a horizontal one.
      height: paper.effectivePanelMm * PdfPageFormat.mm,  // 29mm
      color: PdfColors.white,
      child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        child: pw.Row(children: [
          // ── Left: QR code ────────────────────────────────────────────────
          // Placed left so after the driver's 90° rotation it lands at the
          // top of the face oval (within the printable wristband face area).
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: [
              patient.patientId,
              patient.name,
              patient.gender,
              patient.bloodType,
              patient.dateOfBirth,
              patient.department,
              patient.doctor,
              patient.allergy,
              patient.admissionTime,
            ].join('|'),
            width:  qrMm * PdfPageFormat.mm,
            height: qrMm * PdfPageFormat.mm,
            drawText: false,
          ),
          pw.SizedBox(width: 32),
          // ── Right: patient info ──────────────────────────────────────────
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.only(top: 6),
              child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // Name (full width)
                pw.Text(
                  patient.name,
                  style: pw.TextStyle(
                    fontSize: _fontSize(paper, 14.5),
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
                // Patient ID + Blood type
                pw.Row(children: [
                  _infoChip('ID', patient.patientId, paper),
                  pw.SizedBox(width: 3),
                  _infoChip('BLD', patient.bloodType, paper),
                ]),
                // DOB + Gender on the same row
                if (patient.dateOfBirth.isNotEmpty || genderLabel.isNotEmpty)
                  pw.Row(children: [
                    if (patient.dateOfBirth.isNotEmpty)
                      pw.Text(
                        'DOB: ${patient.dateOfBirth}',
                        style: pw.TextStyle(
                            fontSize: _fontSize(paper, 7.5), color: PdfColors.grey700),
                        maxLines: 1,
                      ),
                    if (patient.dateOfBirth.isNotEmpty && genderLabel.isNotEmpty)
                      pw.SizedBox(width: 8),
                    if (genderLabel.isNotEmpty)
                      pw.Text(
                        'Gender: $genderLabel',
                        style: pw.TextStyle(
                          fontSize: _fontSize(paper, 7.5),
                          fontWeight: pw.FontWeight.bold,
                          color: patient.gender == 'Female'
                              ? PdfColors.pink700
                              : PdfColors.blue700,
                        ),
                        maxLines: 1,
                      ),
                  ]),
                // Department + Doctor
                pw.Row(children: [
                  _infoChip('Dept', patient.department, paper),
                  pw.SizedBox(width: 3),
                  _infoChip('Dr', patient.doctor, paper),
                ]),
                // Allergy warning — red background, always visible
                if (hasAllergy)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                    color: PdfColors.red,
                    child: pw.Text(
                      'ALLERGY: ${patient.allergy}',
                      style: pw.TextStyle(
                          fontSize: _fontSize(paper, 7.5), color: PdfColors.white),
                      maxLines: 1,
                    ),
                  ),
                // Admission time
                pw.Text(
                  patient.admissionTime,
                  style: pw.TextStyle(
                      fontSize: _fontSize(paper, 7.5), color: PdfColors.grey),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          ),
        ]),
      ),
    );
  }

  /// Scale base font size proportionally to the printable panel (short axis).
  ///
  /// Deliberately the panel, not the full band width: on stock where the two
  /// differ, sizing off the band overshoots and the text runs past the panel.
  double _fontSize(PaperConfig paper, double base) =>
      base * (paper.printablePanelMm / 29.0);

  pw.Widget _infoChip(String label, String value, PaperConfig paper) {
    if (value.isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
      ),
      child: pw.Text(
        '$label: $value',
        style: pw.TextStyle(fontSize: _fontSize(paper, 8.5)),
        maxLines: 1,
      ),
    );
  }

  /// Landscape face-only PDF for on-screen preview.
  ///
  /// Mirrors the Windows print path exactly, print offset included — a preview
  /// that showed the content in a different spot than the band comes out would
  /// be worse than no preview at all.
  Future<Uint8List> previewWristband(Patient patient) async {
    final paper = PaperConfig.byItemNo(SettingsService.instance.selectedPaperItemNo);
    final cjkFont = await _loadCjkFont();
    final doc = pw.Document(theme: pw.ThemeData.withFont(fontFallback: [cjkFont]));
    final offsetMm = paper.printOffsetMm;
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat(
        paper.faceMm  * PdfPageFormat.mm,  // 110mm — landscape width
        paper.widthMm * PdfPageFormat.mm,  // 29mm  — landscape height
      ),
      margin: pw.EdgeInsets.zero,
      build: (_) {
        final face = _buildFaceContent(patient, paper, faceWidthMm: paper.faceMm - offsetMm);
        final body = offsetMm == 0
            ? face
            : pw.Row(children: [
                pw.SizedBox(width: offsetMm * PdfPageFormat.mm),
                face,
              ]);
        return _verticalPosition(paper, body, paper.widthMm);
      },
    ));
    return doc.save();
  }
}
