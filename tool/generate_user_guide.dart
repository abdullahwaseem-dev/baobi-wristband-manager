// Regenerates docs/Baobi_Wristband_User_Guide.pdf from scratch.
//
// There is no separate source (markdown/HTML) behind that PDF, so updating it
// means rebuilding the whole document. Content below is the original guide
// transcribed faithfully, plus the revisions listed here.
//
// v1.1:
//   - Section 9 updated for the wristband stock count going from 19 -> 37
//     (see lib/models/paper_config.dart for where those numbers come from).
//   - One sentence in Section 1 corrected: it claimed the app never sends
//     data anywhere except pulling from HIS, which predates the app's
//     Cloud Sync (Firebase) feature and is no longer accurate.
//   - Section 12 (Cloud Sync) added — the feature postdates the original guide.
//
// v1.2:
//   - Section 9 gained a key for the paper picker's source colour dot (blue =
//     Baobi Configuration Reference, violet = "Black Bar position" spec sheets)
//     and a subsection on the black registration bar: where it sits per closure
//     type, and that printing starts immediately after it rather than at the
//     edge of the strip. Section 9 is now a MultiPage, since it no longer fits
//     on one.
//   - Section 9 also documents the 10mm print offset applied to the spec-sheet
//     stocks (PaperConfig.specSheetPrintOffsetMm), measured off a test print.
//
// v1.3:
//   - Stock count 37 -> 36. BVP14200B, BVP14220B and BVP14410B now use the
//     snap sheet's dimensions instead of the Configuration Reference's, which
//     removed the duplicated BVP14410B reading (see paper_config.dart).
//
// v1.4:
//   - Stock count 36 -> 35, and the table is now sheet-first: one entry per
//     item number printed on the two spec sheets (31), plus only those
//     Configuration Reference stocks the sheets never mention (4). Reference
//     rows that clashed with a sheet were deleted rather than kept under a
//     suffix, so no item number appears twice any more and the "APPEAR TWICE"
//     callout is gone.
//   - Every adhesive stock is now sized against the sheet's inner printable
//     panel rather than the full band width (PaperConfig.panelMm).
//
// v1.5:
//   - Section 12 rewritten top to bottom. Cloud Sync moved from "one shared
//     login per hospital" to one account per person, and signing in is now
//     REQUIRED before Patient List, Print, or Print Queue can be opened at
//     all (they show a "Sign in to continue" screen otherwise) — the old
//     text described Cloud Sync as optional, which is no longer true.
//   - New section 13, "Staff accounts, departments and the admin screen":
//     the three roles (Admin/Staff/Viewer), why a signed-in account only
//     sees its own department's patients, the Unassigned Patients queue for
//     imports that didn't match a known department, and a walkthrough of
//     Manage Staff & Departments (admin-only). Sections 13-15 renumbered to
//     14-16 accordingly.
//   - Section 1 and the Home screen section (4) updated for sign-in now
//     being mandatory rather than optional.
//   - Section 5's Department field and the Troubleshooting table updated for
//     department now being chosen from a list instead of typed freely.
//
// v1.6:
//   - Section 9 updated for real BB720A test-print corrections on 14 snap-
//     closure stocks (individually measured print offsets replacing the flat
//     10mm default) plus a new width-axis correction (content offset from the
//     band's top or bottom edge) on those same stocks and the BVP14350/14360
//     adhesive-closure families. BVP14400F/14410F/14420F also moved off the
//     Configuration Reference onto their B-sibling's real geometry, dropping
//     the reference-only count from 4 to 1 (34 spec-sheet stocks, up from 31).
//
// v1.7:
//   - Department-level accounts (roles, per-department data separation, the
//     admin screen) have been removed. Cloud Sync is back to one shared
//     login per hospital, and it's optional again — Patient List, Print and
//     Print Queue all work without signing in, exactly as before v1.5.
//     Section 12 rewritten back to that model; former section 13 ("Staff
//     accounts, departments and the admin screen") is gone entirely, and
//     the sections after it are renumbered down by one (13-15).
//   - Section 1, the Home screen section (4) and Section 5's Department
//     field description reverted to match: sign-in is optional, and
//     Department on the Print/Add/Edit forms is a plain typed field again.
//   - Troubleshooting table's sign-in-gate and unassigned-patient rows
//     removed accordingly.
//   - Section 11 (HIS Connection) documents a new Department field on the
//     Connection tab: a fixed value sent to your HIS as its own request
//     parameter on every call, so the HIS can filter/scope what it returns
//     by department. This is a separate, standalone integration parameter —
//     distinct from the Field Map tab's Department row, which only tells
//     the app which JSON key holds a department NAME in the HIS's response.
//
// v1.8:
//   - A second round of real BB720A test prints (Wristband Position
//     Deviation PDF) re-measured 16 stocks. No user-facing prose changed —
//     Section 9 already describes the offset/inset feature generically
//     rather than enumerating exact mm figures — but the underlying
//     PaperConfig table did, so anyone printing on BVP14200B, 14210B,
//     14220B, 14250B, 14350B/F/15350/-DS, 14360B/F/15360/-DS, 14380B/F/15380,
//     14390B/F/15390, 14400B/F, 14410B/F, 14420F, 14430B, 14460B, 14470B,
//     14480B or 14490B should update to this release.
//   - Section 11 gained a callout clarifying that HIS sync is manual only
//     (Save / Sync HIS / Sync All Patients) and never runs automatically in
//     the background, unlike Cloud Sync — worth stating explicitly since the
//     two sit right next to each other in this guide and behave differently.
//
// v1.9:
//   - Automatic background HIS sync added (a 5-minute periodic pull, mirroring
//     Cloud Sync's own background timer, just less frequent since a full HIS
//     pull is heavier than Cloud Sync's incremental one). The v1.8 callout
//     saying HIS sync was manual-only is now the opposite of true and has
//     been rewritten accordingly. The manual triggers (Save / Sync HIS / Sync
//     All Patients) are unchanged and still work exactly as before — this is
//     purely additive.
//
// Run with:
//   dart run tool/generate_user_guide.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ─── Palette (matches AppColors.applyLight() in lib/core/app_theme.dart) ────
const _emerald = PdfColor.fromInt(0xFF00A878);
const _navy = PdfColor.fromInt(0xFF1A5276);
const _brandBlue = PdfColor.fromInt(0xFF2563EB);
const _textDark = PdfColor.fromInt(0xFF1A2332);
const _textMuted = PdfColor.fromInt(0xFF708090);
const _violet = PdfColor.fromInt(0xFF7C3AED);
const _mintBg = PdfColor.fromInt(0xFFE4F2EC);
const _warningBg = PdfColor.fromInt(0xFFFEF3E2);
const _warningOrange = PdfColor.fromInt(0xFFD97706);
const _borderGray = PdfColor.fromInt(0xFFE2E8F0);
const _zebraRow = PdfColor.fromInt(0xFFF3F9F6);
const _white = PdfColors.white;

const _margin = pw.EdgeInsets.fromLTRB(56, 50, 56, 50);

pw.Page _page(pw.Widget child) => pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: _margin,
      build: (ctx) => child,
    );

pw.MultiPage _multiPage(List<pw.Widget> children) => pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: _margin,
      build: (ctx) => children,
    );

// ─── Building blocks ─────────────────────────────────────────────────────────

pw.Widget _sectionHeader(String title) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _textDark)),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, width: double.infinity, color: _emerald),
        pw.SizedBox(height: 16),
      ],
    );

pw.Widget _subhead(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 8),
      child: pw.Text(title, style: pw.TextStyle(fontSize: 12.5, fontWeight: pw.FontWeight.bold, color: _navy)),
    );

pw.Widget _para(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 10.2, color: _textDark, lineSpacing: 2.5)),
    );

/// A bullet whose first `bold` words are emphasized, followed by plain `rest`.
pw.Widget _boldBullet(String bold, String rest) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('•  ', style: pw.TextStyle(color: _emerald, fontWeight: pw.FontWeight.bold, fontSize: 10.2)),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: bold, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: _textDark, fontSize: 10.2)),
              pw.TextSpan(text: rest, style: const pw.TextStyle(color: _textDark, fontSize: 10.2)),
            ]),
          ),
        ),
      ]),
    );

pw.Widget _plainBullet(String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('•  ', style: pw.TextStyle(color: _emerald, fontWeight: pw.FontWeight.bold, fontSize: 10.2)),
        pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(color: _textDark, fontSize: 10.2))),
      ]),
    );

pw.Widget _numbered(int n, String text) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.SizedBox(
          width: 16,
          child: pw.Text('$n.', style: pw.TextStyle(color: _emerald, fontWeight: pw.FontWeight.bold, fontSize: 10.2)),
        ),
        pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(color: _textDark, fontSize: 10.2))),
      ]),
    );

pw.Widget _cell(String text, {bool header = false, bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9.5,
          color: header ? _white : _textDark,
          fontWeight: (header || bold) ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

pw.Widget _table(List<String> headers, List<List<String>> rows, {List<int>? flex}) {
  final widths = <int, pw.TableColumnWidth>{};
  if (flex != null) {
    for (var i = 0; i < flex.length; i++) {
      widths[i] = pw.FlexColumnWidth(flex[i].toDouble());
    }
  }
  return pw.Table(
    border: pw.TableBorder.all(color: _borderGray, width: 0.6),
    columnWidths: widths,
    children: [
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: _navy),
        children: headers.map((h) => _cell(h, header: true)).toList(),
      ),
      for (var i = 0; i < rows.length; i++)
        pw.TableRow(
          decoration: pw.BoxDecoration(color: i.isOdd ? _zebraRow : _white),
          children: rows[i].map((c) => _cell(c)).toList(),
        ),
    ],
  );
}

/// A coloured dot matching one in the app's paper picker, followed by what it
/// means. Used for the source key in section 9.
pw.Widget _swatchRow(PdfColor color, String bold, String rest) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7, left: 4),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(
          width: 8,
          height: 8,
          margin: const pw.EdgeInsets.only(top: 3, right: 8),
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.Expanded(
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: bold, style: pw.TextStyle(fontSize: 10.2, fontWeight: pw.FontWeight.bold, color: _textDark)),
              pw.TextSpan(text: rest, style: const pw.TextStyle(fontSize: 10.2, color: _textDark, lineSpacing: 2.5)),
            ]),
          ),
        ),
      ]),
    );

pw.Widget _calloutBox(String label, String body, {bool warning = false}) => pw.Container(
      margin: const pw.EdgeInsets.only(top: 4, bottom: 4),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: warning ? _warningBg : _mintBg,
        border: pw.Border(left: pw.BorderSide(color: warning ? _warningOrange : _emerald, width: 3)),
      ),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: _textDark, letterSpacing: 0.3)),
        pw.SizedBox(height: 5),
        pw.Text(body, style: const pw.TextStyle(fontSize: 9.8, color: _textDark, lineSpacing: 2)),
      ]),
    );

// ─── Document ────────────────────────────────────────────────────────────────

Future<void> main() async {
  // Base14 Helvetica (the pw package's default) has no glyphs for em-dash,
  // the bullet character, the right-arrow, or CJK — all used throughout this
  // doc's body text. Falling back to the same Noto Sans CJK font already
  // shipped for wristband printing (see print_service.dart) covers all of
  // them without changing how plain Latin text looks.
  final fontBytes = await File('assets/fonts/NotoSansCJKsc-Regular.ttf').readAsBytes();
  final fallbackFont = pw.Font.ttf(fontBytes.buffer.asByteData());
  final doc = pw.Document(
    title: 'Baobi Medical Wristband Printing Software - User Guide',
    theme: pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      fontFallback: [fallbackFont],
    ),
  );

  // Page 1 — cover
  doc.addPage(_page(
    pw.Center(
      child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
        pw.Text('BAOBI', style: pw.TextStyle(fontSize: 42, fontWeight: pw.FontWeight.bold, color: _brandBlue)),
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: pw.BoxDecoration(color: _emerald, borderRadius: pw.BorderRadius.circular(12)),
          child: pw.Text('USER GUIDE', style: pw.TextStyle(color: _white, fontSize: 11, fontWeight: pw.FontWeight.bold, letterSpacing: 1)),
        ),
        pw.SizedBox(height: 34),
        pw.Text('Baobi Medical Wristband', textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: _textDark)),
        pw.Text('Printing Software', textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: _textDark)),
        pw.SizedBox(height: 18),
        pw.Text('For use with the BB720A thermal wristband printer',
            style: pw.TextStyle(fontSize: 13, color: _navy)),
        pw.SizedBox(height: 70),
        pw.Text('Version 1.9', style: const pw.TextStyle(fontSize: 10, color: _textMuted)),
        pw.Text('Baobiwanxiang Technologies Co., Limited', style: const pw.TextStyle(fontSize: 10, color: _textMuted)),
        pw.Text('August 2026', style: const pw.TextStyle(fontSize: 10, color: _textMuted)),
      ]),
    ),
  ));

  // Page 2 — contents
  const toc = [
    'Before you start',
    'Installing the software',
    'Getting around the app',
    'The Home screen',
    'Printing a wristband',
    'Managing your patient list',
    'Importing and exporting from Excel',
    'The print queue / history',
    'Setting up the printer (paper size, name, channel)',
    'WiFi, admin password and firmware',
    'Connecting to your hospital system (HIS)',
    'Cloud Sync — keeping your patient list synced across stations',
    'Dark mode, light mode and language',
    'Troubleshooting',
    'Getting help',
  ];
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('Contents', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: _textDark)),
      pw.SizedBox(height: 10),
      pw.Container(height: 2, width: double.infinity, color: _emerald),
      pw.SizedBox(height: 20),
      for (var i = 0; i < toc.length; i++)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(children: [
            pw.SizedBox(
                width: 22,
                child: pw.Text('${i + 1}.', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _emerald))),
            pw.Text(toc[i], style: const pw.TextStyle(fontSize: 11.5, color: _textDark)),
          ]),
        ),
    ]),
  ));

  // Page 3 — 1. Before you start
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('1. Before you start'),
      _para("This guide walks you through the Baobi wristband printing software from the moment you install "
          "it to day-to-day printing and patient record keeping. It's written for the people who'll actually "
          "be sitting at the desk using it — admissions staff, ward clerks, whoever ends up printing the "
          "bands — so we've kept the jargon down and tried to show every screen you'll run into."),
      _para('A few things worth knowing before you install anything:'),
      _boldBullet('The software runs on Windows 10 (64-bit) or later', ". It won't run on Windows 7/8 or on Mac/Linux."),
      _boldBullet('It\'s built to work with the Baobi BB720A', ' thermal wristband printer, connected either over USB '
          "or your local network, using the printer's own Windows driver."),
      _boldBullet('Cloud Sync is optional but recommended. ', "Signing in with your hospital's shared Cloud Sync "
          'login (section 12) keeps the patient list and print history in sync across every station in the '
          "building. You can use the app fully without ever signing in — patients print and save locally on "
          'this one PC either way.'),
      _boldBullet('Your hospital\'s own system (HIS) connection is separate and optional. ', 'If your hospital '
          "has its own patient database, connecting to it (section 11) saves staff from retyping records that "
          'already exist there. It is strictly one-way — it only pulls from your HIS, never pushes anything back.'),
      _para("Day-to-day printing itself doesn't need an internet connection at all — the app works fully "
          "offline, saving everything locally. You only need network access to sign in and sync with Cloud "
          "Sync, to sync with a HIS, or to print to a network-attached printer."),
      pw.SizedBox(height: 6),
      _calloutBox('WHAT YOU\'LL NEED',
          'A Windows PC with the printer driver already installed (this normally comes with the printer or from '
          'your Baobi representative), the printer connected and powered on, and about five minutes to run '
          'through installation.'),
    ]),
  ));

  // Page 4 — 2. Installing the software
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('2. Installing the software'),
      _para("You'll have received a single file from us named something like Baobi_Wristband_Setup_v1.0.0.exe. "
          "That's the entire installer — there's nothing else to download."),
      _subhead('Step by step'),
      _numbered(1, "Copy the installer file onto the PC you'll be printing from."),
      _numbered(2, 'Double-click it to run. Windows may show a blue "Windows protected your PC" screen the '
          "first time, since the installer isn't yet registered with Microsoft — this is normal for new "
          'business software. Click More info, then Run anyway.'),
      _numbered(3, 'The setup wizard will ask where to install the app. Unless you have a reason to change it, '
          'just leave the default location and click Next.'),
      _numbered(4, "You'll be asked if you want a desktop shortcut. We'd recommend leaving this ticked — it "
          'makes it much quicker to open the app each morning.'),
      _numbered(5, 'Click Install, wait a few seconds, then click Finish. The app will open automatically once '
          'installation completes.'),
      pw.SizedBox(height: 4),
      _calloutBox('NOTE',
          'The installer does not require administrator rights by default — it installs to your own user account. '
          'If your hospital IT department has locked down software installs, you may need to ask them to '
          'approve it once.'),
      pw.SizedBox(height: 6),
      _subhead('Uninstalling'),
      _para('If you ever need to remove the software, go to Settings → Apps → Installed apps in Windows, find '
          '"Baobi Medical Wristband" in the list, and click Uninstall. This also removes the shortcut, but your '
          "patient database file is left untouched in case you're reinstalling."),
    ]),
  ));

  // Pages 5-6 — 3. Getting around the app
  doc.addPage(_multiPage([
    _sectionHeader('3. Getting around the app'),
    _para('When you open the app you\'ll land on the Home screen. The layout stays the same wherever you go in '
        'the app: a thin bar across the top, a narrow strip of icons down the left, and the main content in '
        'the middle.'),
    _subhead('The left sidebar'),
    _para('Four icons, always visible:'),
    _table(
      ['Icon', 'Takes you to'],
      [
        ['Home', 'Your dashboard — quick stats, settings shortcuts, and a preview of recent activity.'],
        ['Print', "The manual print form — where you type in (or pull from HIS) one patient's details and print a band."],
        ['Patient List', 'Every patient stored in the system, with search, filtering, and Excel import/export.'],
        ['Print Queue', 'A history of every wristband printed so far, including the codes that were encoded onto each one.'],
      ],
      flex: [1, 3],
    ),
    pw.SizedBox(height: 10),
    _para("If there are prints waiting or recently completed, you'll see a small green number badge under the icons showing the count."),
    _subhead('The top bar'),
    _para('On the left is the Baobi logo. In the middle is the page title so you always know where you are. '
        'On the right there are two controls you\'ll use often:'),
    _boldBullet('The theme toggle', ' — switches between dark mode and light mode. Whichever one is easier on your eyes for your desk\'s lighting.'),
    _boldBullet('The language switcher', ' — three buttons, EN / AR / 中, for English, Arabic and Chinese. Tap one and every label in the app changes immediately — no restart needed.'),
  ]));

  // Pages 7-8 — 4. The Home screen
  doc.addPage(_multiPage([
    _sectionHeader('4. The Home screen'),
    _para("Think of Home as your dashboard. Nothing here is required reading before you print your first band, but it's worth knowing what each part does."),
    _subhead('The four stat cards along the top'),
    _table(
      ['Card', 'What it shows'],
      [
        ['Total patients', 'How many patients are currently stored. Tap it to jump straight to the Patient List.'],
        ['Total prints', 'How many wristbands have been printed. Tap it to open the Print Queue.'],
        ['Ready to Print', 'A green "Ready" badge means the app believes the printer is good to go. If it says "Offline," check the printer connection before you try printing.'],
        ['WiFi', 'Shows the currently connected network name, or "Not set" if WiFi hasn\'t been configured on the printer terminal yet.'],
      ],
      flex: [1, 3],
    ),
    pw.SizedBox(height: 10),
    _subhead('System Settings card'),
    _para('This is where the printer and connection settings live:'),
    _boldBullet('Set WiFi', ' — configure the wireless network the printer connects through (details in section 10).'),
    _boldBullet('Set Password', " — set or change an admin password that locks down the WiFi and firmware settings so staff can't change them by accident."),
    _boldBullet('Firmware Version', " — shows the printer's current firmware and lets you check for updates."),
    _boldBullet('HIS Connection', " — connect the app to your hospital's patient database so you don't have to type everything by hand (section 11 covers this in full)."),
    _boldBullet('Cloud Sync', " — sign in with your hospital's shared Cloud Sync login to keep the patient list "
        'and print history synced across every station (section 12). Entirely optional — everything else in '
        'the app works the same whether you\'re signed in or not.'),
    _subhead('Print Settings card'),
    _boldBullet('Print Speed and Print Density', ' — gears 6 through 15 that control how fast the printer feeds and how dark the print comes out. 14 is the factory default and works fine for most paper stock.'),
    _boldBullet('Paper Size', ' — which of the 35 supported BB720A wristband stocks you\'re using (section 9).'),
    _subhead('Recent Patients and Recent Prints'),
    _para('Two lists at the bottom of Home give you a quick look at the last few patients added and the last few bands printed, without having to go dig through the full list. Click "View All" on either card to see the complete list.'),
    pw.SizedBox(height: 4),
    _calloutBox('ABOUT THE PADLOCK ICONS',
        "If you've set an admin password, you'll notice a small shield icon next to WiFi and Firmware Version. "
        "That means those two settings are locked — anyone tapping them will be asked for the admin password "
        "first. This stops ward staff from accidentally changing the network or firmware. The password setting "
        "itself is never locked, since that's how you'd unlock everything else."),
  ]));

  // Pages 9-10 — 5. Printing a wristband
  doc.addPage(_multiPage([
    _sectionHeader('5. Printing a wristband'),
    _para('This is the page you\'ll use the most. Click Print in the sidebar to get here.'),
    _para('The screen is split in two: a form on the left where you enter the patient\'s details, and a live preview of the actual wristband on the right, updating as you type.'),
    _subhead('Filling in the form'),
    _table(
      ['Field', 'What to enter'],
      [
        ['Patient Name *', 'Full name as it should appear on the band.'],
        ['Patient ID *', 'The hospital/admission ID number. This is also what gets encoded into the QR code.'],
        ['Gender', 'Male or Female — pick with the two-button switch.'],
        ['Blood Type', 'Choose from the blood type picker.'],
        ['Department', "The patient's ward or department — type it in freely."],
        ['Doctor', "The attending physician's name."],
        ['Allergy History', 'Leave as "None" or list known allergies — if anything is entered here, it prints as a bold red warning strip on the band so it can\'t be missed.'],
        ['Date of Birth', 'Tap the field to open a calendar picker rather than typing it by hand.'],
        ['Admission Time', 'Tap to open a combined date and time picker.'],
      ],
      flex: [1, 3],
    ),
    pw.SizedBox(height: 8),
    _para("* Required — the app won't let you print without these two filled in."),
    _subhead('Pulling data from your hospital system instead of typing it'),
    _para('If your HIS connection is set up (section 11), type the Patient ID into the ID field and click Sync HIS at the top of the form. The app will look the patient up and fill in every other field automatically — name, DOB, blood type, department, doctor, allergy, the lot. You can still edit any field afterwards if something needs correcting.'),
    _subhead('The live preview'),
    _para('The card on the right mirrors exactly what will print on the physical band: the QR code on the left (encoding all the patient details), and the text information on the right in the same layout the printer will produce. If a field is empty, the preview shows a placeholder so you can see what\'s still missing.'),
    _subhead('The three buttons under the preview'),
    _boldBullet('Default', ' — clears the form back to a blank state (Male, blood type A+, everything else empty). Use this between patients.'),
    _boldBullet('Clear', " — same effect as Default, just a second button in case that's more natural for your workflow."),
    _boldBullet('Print', "— sends the job to the printer. You'll see a spinner while it's printing, then a green confirmation message once it's done, or a red one telling you to check the printer if something went wrong."),
    pw.SizedBox(height: 4),
    _calloutBox('WHAT HAPPENS AFTER YOU PRINT',
        'Every successful print is automatically saved into the Patient List (if it\'s a new patient) and logged '
        'in the Print Queue with a unique EPC and TID code, so you always have a record of exactly what was '
        'printed and when.'),
  ]));

  // Page 11 — 6. Managing your patient list
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('6. Managing your patient list'),
      _para('Click Patient List in the sidebar to see every patient currently stored in the system, shown as a '
          'card per patient: name, ID, gender, date of birth, blood type, allergy, department, doctor and '
          'admission date, with large Edit / Print / Delete buttons on each card.'),
      _subhead('The toolbar above the list'),
      _boldBullet('Search box', ' — type a name or ID and press Enter to filter the list instantly.'),
      _boldBullet('Filter', " — narrow the list further by gender, blood type, or department. The filter button turns orange when a filter is active, so you don't forget one's applied."),
      _boldBullet('Add', ' — opens a form to add a new patient by hand without going through the Print screen.'),
      _boldBullet('Import and Export', ' — bulk-load patients from an Excel file, or save the current list out to one. Covered in full in section 7.'),
      _boldBullet('Refresh from Cloud', ' — forces an immediate sync rather than waiting for the automatic background one, pulling in anything added at other stations.'),
      _subhead('Working with a card'),
      _para('Each patient card has three large, clearly labeled buttons: Print (reprint a band for that patient without re-entering anything), Edit (opens the same form as Add, pre-filled), and Delete (asks for confirmation first — this can\'t be undone, so double-check before confirming).'),
      _subhead('Paging through a long list'),
      _para('The list loads 20 patients at a time. Use the Prev / Next buttons at the bottom to move through pages — the current page number is shown in the middle, and the total patient count is shown on the left so you always know how far through you are.'),
    ]),
  ));

  // Page 12 — 7. Importing and exporting from Excel
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('7. Importing and exporting from Excel'),
      _para("If you already keep a spreadsheet of admissions, or you need to hand a batch of records to someone else, you don't have to type everything into the app one row at a time."),
      _subhead('Importing'),
      _para('Click Import on the Patient List toolbar and choose an .xlsx file. The app reads the first sheet, treats row 1 as a header row, and expects the following column order starting from column A:'),
      _table(
        ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I'],
        [
          ['Name', 'Patient ID', 'Gender', 'Date of Birth', 'Department', 'Blood Type', 'Allergy', 'Admission Time', 'Doctor'],
        ],
      ),
      pw.SizedBox(height: 8),
      _para('Rows where both Name and Patient ID are blank get skipped automatically, so a stray blank line in your spreadsheet won\'t cause an error. If Gender or Blood Type are left blank, the app fills in "Male" and "A+" as sensible defaults rather than rejecting the row.'),
      _calloutBox('BEFORE YOU IMPORT', 'Save your spreadsheet as .xlsx (not the older .xls format), and make sure the columns are in the order shown above. If the file doesn\'t match, you\'ll get an "Import failed" message — double check the column order and file format and try again.', warning: true),
      pw.SizedBox(height: 6),
      _subhead('Exporting'),
      _para('Click Export and the app writes every patient currently in the system out to a new .xlsx file, using the same nine columns, saved into your Windows Documents folder with a filename that includes the date (e.g. baobi_patients_20260704.xlsx). Handy for backups, or for handing a snapshot of the list to someone who needs it in Excel.'),
    ]),
  ));

  // Page 13 — 8. The print queue / history
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('8. The print queue / history'),
      _para('Every wristband ever printed shows up here, oldest at the bottom. It\'s your audit trail — useful if someone asks "did we print a band for this patient, and when?"'),
      _para('Each row shows the patient\'s name, ID, blood type and department, plus two codes you won\'t see anywhere else in the app:'),
      _boldBullet('EPC Code', ' — a unique code generated for that specific print.'),
      _boldBullet('TID Code', ' — a second unique identifier tied to the same print job.'),
      _para('These exist mainly for traceability — if a band ever needs to be matched back to exactly which print job produced it, these codes are how you\'d do it.'),
      _para('Search and filter work the same way as on the Patient List page, except filtering here is by department and date range rather than gender or blood type — handy for pulling "everything printed last Tuesday" or "everything for Cardiology this month."'),
    ]),
  ));

  // Pages 14-15 — 9. Setting up the printer (UPDATED for this revision)
  doc.addPage(_multiPage([
    _sectionHeader('9. Setting up the printer'),
    _para('Open this from Home → Print Settings → Paper Size. You\'ll rarely need to touch this after the initial setup, but it\'s important to get right — the wrong paper size will cause misaligned or cut-off prints.'),
    _subhead('Choosing your paper stock'),
    _para('The BB720A supports 35 wristband stocks — 34 of them covering every item number on Baobi\'s two '
        '"Black Bar position" spec sheets, plus 1 older size those sheets don\'t mention. Your Baobi '
        'representative will have told you which item number your hospital ordered — look for it in the list '
        '(e.g. BB720_BVP14200B) and tap it to select it. The face size and width are shown next to each option '
        'so you can double check against the box your paper stock came in. Each item number appears exactly '
        'once, so if you find your code in the list, it is the right one.'),
    _subhead('The colour dot next to each stock'),
    _para('Every row in the list starts with a coloured dot telling you which Baobi document that stock\'s '
        'measurements were taken from, so you know which sheet to check if the numbers ever need verifying:'),
    _swatchRow(_brandBlue, 'Blue', ' — from the older Baobi Configuration Reference. Only one stock is left on '
        'this: BVP15480, the one size neither spec sheet mentions at all.'),
    _swatchRow(_violet, 'Violet', ' — from Baobi\'s two "Black Bar position" spec sheets, covering the '
        'adhesive-closure and snap-closure ranges. These 34 rows also carry a small violet PDF tag next to the '
        'item number, so you can still tell them apart on a black-and-white screen or printout.'),
    _calloutBox('MOST STOCKS WERE RE-MEASURED IN THIS RELEASE',
        'Every item number the two spec sheets cover now uses that sheet\'s dimensions. Where an older figure '
        'disagreed — and on several stocks it disagreed by roughly three times — the older one has been '
        'removed rather than kept alongside, so each item number now appears exactly once in the list and '
        'means exactly one size. If your hospital has been printing happily on a particular stock, run one '
        'test band after updating to confirm it still lines up before doing a full batch.', warning: true),
    _calloutBox('ONE LABELLING CLASH, SETTLED',
        'The snap-closure sheet prints "BVP14410B" over two different bands. In the app, BVP14410B is the '
        '25 mm one; the 19 mm one is listed under its partner code BVP14220B. If your box says BVP14410B, '
        'check its width against the mm figures in the list before selecting.'),
    pw.SizedBox(height: 6),
    _subhead('Where printing starts: the black bar'),
    _para('Every Baobi band has a short black bar printed across it a fixed distance in from the leading edge. '
        'That bar is what the printer looks for. It feeds the strip until its sensor sees the bar, stops, and '
        'begins printing immediately after it. Nothing is printed on the run-up before the bar — that stretch '
        'is the adhesive tab or the snap tail, and it stays blank by design.'),
    _para('How far in the bar sits depends on which closure type your stock uses:'),
    _table(
      ['Stock type', 'Black bar sits', 'Item numbers'],
      [
        ['Adhesive closure', '5 mm from the leading edge',
            'All BVP143xx and BVP153xx codes (14340/14350/14360/14380/14390 in their F, B and 153xx forms), '
            'plus BVP14250B, BVP12340-DS and the -DS variants'],
        ['Snap closure', '40 mm in, just past the snap tail',
            'BVP14200B, BVP14200F, BVP14210B, BVP14210F, BVP14220B, BVP14400B, BVP14400F, BVP14410B, BVP14410F, '
            'BVP14420F, BVP14430B, BVP14460B'],
        ['Snap closure (short tail)', '35 mm in, just past the snap tail',
            'BVP14470B, BVP14480B, BVP14490B'],
      ],
      flex: [3, 4, 7],
    ),
    pw.SizedBox(height: 10),
    _para('The app already accounts for all of this — there is no offset to enter anywhere. Each row in the '
        'paper list shows its bar distance beside a small black marker, and the panel at the bottom of the '
        'dialog spells it out in full for whichever stock you have selected ("Black bar 5 mm from lead edge — '
        'printing starts immediately after it"). Pick the item number that matches your box and the content '
        'will land in the right place on the band.'),
    _para('Every spec-sheet stock additionally carries a small built-in print offset, shown in that same panel '
        'as e.g. "Print offset +20 mm" — how far past the black bar this specific stock\'s content actually '
        'needs to start, confirmed on a real BB720A rather than assumed. Most stocks share the same figure; a '
        'handful of the snap-closure stocks (the BVP14200/14210/14220/14400/14410/14420/14430/14460/14470/'
        '14480/14490 family) were individually re-measured and carry their own, larger figure instead. Either '
        'way it\'s applied automatically — nothing to set — and the print preview on the Print screen shows the '
        'shifted position, so what you see there is what comes out of the printer.'),
    _para('That same family, plus BVP14350 and BVP14360\'s adhesive-closure group, also carry a small measured '
        'adjustment across the band\'s width — content sitting a defined distance from the band\'s top or '
        'bottom edge rather than dead centre. Same idea as the print offset: automatic, based on a real test '
        'print, nothing to configure.'),
    _calloutBox('IF YOUR PRINT LANDS IN THE WRONG PLACE',
        'First check the mm figures shown in the Paper Size dialog against the box your stock came in — by far '
        'the most common cause is simply the wrong item number being selected, especially between two entries '
        'sharing a prefix. If those match and the print is still shifted along the band, the printer itself may '
        'not be set to black-mark sensing; Baobi support can confirm the correct media-type setting for your '
        'unit (section 15).', warning: true),
    pw.SizedBox(height: 6),
    _subhead('Printer name'),
    _para('This field has to match, exactly, the name your printer shows up as in Windows. To check: open '
        'Settings → Bluetooth & devices → Printers & scanners in Windows, and copy the name shown there for '
        'your Baobi/BB720A printer into this field. If the names don\'t match, the app won\'t be able to find '
        'your printer.'),
    _subhead('Print channel'),
    _para('Choose Upper feed, Lower feed, or Printer default depending on which paper channel your printer is '
        'loaded from. If you\'re not sure, "Printer default" is the safest starting point.'),
    _subhead('Print speed and density'),
    _para('Back on Home, under Print Settings, you can also adjust Print Speed and Print Density independently '
        '— both on a scale of gear 6 (slowest / lightest) to gear 15 (fastest / darkest), with gear 14 as the '
        'factory default. If your prints are coming out too light or smudged, try lowering the speed or '
        'raising the density a notch and reprinting a test band.'),
  ]));

  // Page 15 — 10. WiFi, admin password and firmware
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('10. WiFi, admin password and firmware'),
      _subhead('Setting up WiFi'),
      _para('Open Set WiFi from the Home screen. Click Scan to refresh the list of nearby networks, tap the one you want to join, enter its password, and click Connect. Once connected, the network name will show up on the WiFi stat card on Home.'),
      _subhead('Setting an admin password'),
      _para('Open Set Password. The first time you set a password, you\'ll just be asked for a new password and to confirm it. After that, changing it requires the old password first — so if you forget it, you\'ll need to get in touch with support to reset it (see section 15).'),
      _calloutBox('WHY BOTHER WITH A PASSWORD?', 'Once set, it locks the WiFi, Firmware and Cloud Sync settings behind a quick password check, so a change to the network, a firmware update, or signing out of the shared hospital account can\'t happen by accident from a busy ward desk. Day-to-day printing is never affected — this only gates the settings that could disrupt the printer or the shared patient list if changed carelessly.'),
      pw.SizedBox(height: 6),
      _subhead('Checking firmware'),
      _para('Open Firmware Version from Home to see the printer terminal\'s current firmware build. Click Check for Update to have the app check whether a newer version is available.'),
    ]),
  ));

  // Pages 16-17 — 11. Connecting to your hospital system (HIS)
  doc.addPage(_multiPage([
    _sectionHeader('11. Connecting to your hospital system (HIS)'),
    _para('If your hospital already has a patient database or HIS with a REST API, you can connect the wristband app directly to it. Once set up, staff can pull a patient\'s full record just by typing their ID — no more retyping names, DOBs and departments that already exist somewhere else in the hospital\'s systems.'),
    _para('Open this from Home → System Settings → HIS Connection. The dialog has four tabs, and you\'ll normally only need to fill in the first two or three the first time you set it up.'),
    _subhead('Tab 1 — Connection'),
    _para('Enter the base web address of your hospital\'s API, for example http://192.168.1.100:8080/api. This is the address the app will send every request to. Ask your hospital\'s IT or systems team for this if you don\'t already have it — it\'s specific to your HIS setup.'),
    _para('Below it, an optional Department field. Fill this in and it\'s sent to your HIS as its own request '
        'parameter on every call — a fixed value the app always includes, so your HIS can filter or scope the '
        'patient data it returns to just that department. Leave it blank if your HIS integration doesn\'t need '
        'it. This is separate from the Department row on the Field Map tab, which only tells the app which of '
        'your API\'s JSON fields holds a department name in the data that comes back — one is a value the app '
        'sends out, the other is a mapping for data coming in.'),
    _subhead('Tab 2 — Auth'),
    _para('Most hospital systems require some form of authentication before they\'ll hand over patient data. Pick whichever your system uses:'),
    _table(
      ['Option', 'What to fill in'],
      [
        ['No Authentication', 'Nothing further needed — only use this if your HIS API is genuinely open, which is uncommon.'],
        ['Basic Auth', 'A username and password, same as logging into most systems.'],
        ['Bearer Token', 'A long access token your IT department issues — paste it in as-is.'],
        ['API Key Header', 'A custom header name (e.g. X-API-Key) plus its value, if that\'s how your system authenticates.'],
      ],
      flex: [1, 3],
    ),
    pw.SizedBox(height: 8),
    _subhead('Tab 3 — Endpoints'),
    _para('This tells the app exactly which web address to call to fetch one patient\'s data. Use {id} as a stand-in for the patient ID, e.g. /patient/{id} — the app substitutes the real ID in when it makes the request. If your API wraps results inside a named field (e.g. everything is nested under "data" in the JSON response), enter that field name under Response Array Key; otherwise leave it blank.'),
    _subhead('Tab 4 — Field Map'),
    _para('Every hospital\'s API names its fields slightly differently — some call it patient_name, others fullName, others just name. This tab lets you tell the app which of your API\'s exact field names corresponds to each patient field the wristband software understands (name, gender, date of birth, blood type, and so on). Ask whoever manages your HIS API for a sample response if you\'re not sure of the exact field names — matching them precisely here is what makes the sync work.'),
    _subhead('Testing it'),
    _para('Once you\'ve filled in what you need, click Test Connection at the bottom of the dialog. You\'ll get a clear green tick or a red cross telling you whether the app could reach your HIS successfully. Fix anything flagged, test again, then click Save.'),
    _para('After it\'s connected, the Sync HIS button on the Print screen (section 5) and the Sync All Patients option on Home both become available for pulling patient data straight from your hospital\'s system.'),
    _calloutBox('HIS SYNC HAPPENS AUTOMATICALLY, TOO',
        'Once configured, the app quietly re-pulls your HIS roster in the background every 5 minutes — similar to Cloud Sync (section 12), just less frequent since a full HIS pull is a heavier request than Cloud Sync\'s incremental one. You don\'t have to wait for it, though: clicking Save on this dialog, Sync HIS on the Print screen, or Sync All Patients on Home all still trigger an immediate pull on demand.'),
    _calloutBox('ONE-WAY ONLY', 'The HIS connection only ever reads from your hospital\'s system — it never writes or updates anything back to it. Printing a wristband and saving a patient record in this app has no effect on your HIS database.'),
  ]));

  // Pages 18-19 — 12. Cloud Sync (back to one shared login per hospital and
  // optional sign-in as of v1.7 — see the v1.7 changelog note up top)
  doc.addPage(_multiPage([
    _sectionHeader('12. Cloud Sync — keeping your patient list synced across stations'),
    _para('If your hospital has more than one station printing wristbands, Cloud Sync keeps them all showing '
        'the same patient list and print history. There\'s one shared login per hospital, issued by Baobi — '
        'every station signs in with the same account.'),
    _subhead('Signing in'),
    _para('Open Home → System Settings → Cloud Sync, click Sign In, and enter your hospital\'s Cloud Sync '
        'email and password.'),
    _para('The moment you sign in, your hospital\'s full patient list pulls down automatically.'),
    pw.SizedBox(height: 4),
    _calloutBox('YOUR HOSPITAL\'S CLOUD SYNC LOGIN',
        'Email: baobitechnology@gmail.com\n'
        'Password: Baobi@2026\n\n'
        'Use this on every station you want kept in sync. It\'s the same login everywhere — there\'s no '
        'per-person account to set up.', warning: true),
    pw.SizedBox(height: 6),
    _subhead('Keeping in sync day to day'),
    _boldBullet('Automatically, in the background — ', 'no action needed. The app quietly syncs roughly every '
        'minute and a half while you\'re signed in and online.'),
    _boldBullet('Immediately after printing — ', 'a freshly printed wristband is pushed to the cloud right '
        'away rather than waiting for the next automatic cycle.'),
    _boldBullet('Refresh from Cloud, ', 'on the Patient List screen, forces an immediate sync if you don\'t '
        'want to wait for either of the above.'),
    _calloutBox('WORKS OFFLINE, CATCHES UP LATER',
        'Once you\'re signed in, printing keeps working even if the network drops — patients still print and '
        'save locally. Anything added or changed while offline pushes to the cloud automatically the moment '
        'the connection returns, with nothing for you to do.'),
    pw.SizedBox(height: 6),
    _subhead('Signing out'),
    _para('Open Cloud Sync from Home and click Sign Out. This station stops syncing, but nothing already '
        'printed or saved locally is affected.'),
  ]));

  // Page 22 — 13. Dark mode, light mode and language
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('13. Dark mode, light mode and language'),
      _para('Both of these live in the top-right corner of every screen, and take effect immediately — nothing to save, nothing to restart.'),
      _subhead('Dark mode / Light mode'),
      _para('Click the toggle showing a moon or sun icon to switch. Dark mode uses a deep navy background and is easier on the eyes in a dim room; light mode uses a soft seashell-and-mint background with dark text, better suited to a brightly lit ward desk or near a window. Pick whichever\'s more comfortable — it\'s purely a preference and has no effect on printing or data.'),
      _subhead('Language'),
      _para('Three buttons — EN, AR, 中 — switch every label in the app between English, Arabic and Chinese. Your patient data itself isn\'t translated (names, IDs, etc. stay exactly as entered), only the interface labels change.'),
    ]),
  ));

  // Page 20 — 14. Troubleshooting
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('14. Troubleshooting'),
      _table(
        ['Problem', 'What to check'],
        [
          ['"Print failed, check printer" message', 'Make sure the printer is powered on and connected. Check the printer name entered in Paper Size settings matches exactly what Windows shows under Printers & Scanners. Try turning the printer off and on again if it\'s been idle a while.'],
          ['Wristband prints but text is cut off or misaligned', 'Almost always a wrong paper size selection — double check the item number selected under Paper Size against the actual stock loaded in the printer.'],
          ['Print looks too light or smudged', 'Try raising Print Density by a gear or two on Home, and reprint a test band. Also check the ribbon/stock hasn\'t run low.'],
          ['A patient you expect to see isn\'t in the list', 'It likely hasn\'t synced yet if Cloud Sync is in use — try Refresh from Cloud on the Patient List screen, and confirm the station is signed in under Home → Cloud Sync.'],
          ['"Sync failed, check network" when syncing from HIS', 'Confirm the PC has network access to your hospital\'s server address, and re-test the connection under HIS Connection → Test Connection.'],
          ['"Patient not found" when syncing a single patient by ID', 'Double check the ID was typed correctly, and that it actually exists in your HIS. Also check the Search Endpoint under HIS Connection is configured correctly.'],
          ['Import from Excel fails', 'File must be .xlsx (not .xls or .csv), with columns in the order given in section 7.'],
          ['Forgot the admin password', 'There\'s no self-service reset from within the app by design — contact support (section 15) for help resetting it.'],
          ['App won\'t open after installing', 'Confirm you\'re on Windows 10 (64-bit) or newer. Try reinstalling — if it still won\'t open, get in touch with support and let us know what happens (or doesn\'t) when you try to launch it.'],
        ],
        flex: [1, 2],
      ),
    ]),
  ));

  // 15. Getting help
  doc.addPage(_page(
    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      _sectionHeader('15. Getting help'),
      _para('If something in this guide doesn\'t match what you\'re seeing, or you\'ve hit an issue we haven\'t covered here, get in touch with your Baobi representative or contact support directly. It\'s worth having the following on hand when you reach out — it\'ll save a lot of back and forth:'),
      _plainBullet('What you were trying to do when the problem happened'),
      _plainBullet('The exact wording of any error message shown'),
      _plainBullet('Which paper stock (item number) and printer name you\'re using'),
      _plainBullet('A screenshot of the screen in question, if possible'),
      pw.SizedBox(height: 20),
      _para('Thanks for using Baobi. We hope this saves you a fair amount of typing.'),
      pw.SizedBox(height: 30),
      pw.Container(height: 1, width: double.infinity, color: _borderGray),
      pw.SizedBox(height: 10),
      pw.Text('Baobiwanxiang Technologies Co., Limited — Baobi Medical Wristband Printing Software, Version 1.9',
          style: const pw.TextStyle(fontSize: 8.5, color: _textMuted)),
    ]),
  ));

  final outFile = File('docs/Baobi_Wristband_User_Guide.pdf');
  await outFile.writeAsBytes(await doc.save());
  // ignore: avoid_print
  print('Wrote ${outFile.path} (${(await outFile.length())} bytes, ${doc.document.pdfPageList.pages.length} pages)');
}
