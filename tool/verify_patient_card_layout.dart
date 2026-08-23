// ignore_for_file: avoid_print
// Structural verification of the Patient List card redesign — bigger text,
// bigger buttons, same color theme. Renders the exact widget code (copied
// verbatim from patient_list_screen.dart's private card widgets) and asserts
// concrete facts about it: font sizes, button hit-testability, text content,
// allergy highlighting.
//
// Deliberately does NOT call RenderRepaintBoundary.toImage() — confirmed via
// a throwaway probe that toImage() hangs indefinitely in this machine's
// flutter_test host (CPU usage flatlined across repeated samples; a plain
// pumpWidget + find.text with no toImage() call completed instantly), so a
// pixel screenshot isn't obtainable here. This checks the same change
// through widget-tree assertions instead.
//
// Not part of the automated suite (lives in tool/, not test/).
//
// Run with:
//   flutter test tool/verify_patient_card_layout.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baobi_wristband/core/app_theme.dart';
import 'package:baobi_wristband/core/strings.dart';
import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/widgets/glass_container.dart';

void main() {
  AppColors.applyDark();

  final withAllergy = Patient(
    name: 'Natalie Rodriguez', gender: 'Female', patientId: 'A00069', bloodType: 'A+',
    department: 'Anorectal', doctor: 'Dr. Charles Foster', dateOfBirth: '1987-06-14',
    admissionTime: '2026-05-02 16:50', allergy: 'Penicillin',
  );
  final noAllergy = Patient(
    name: 'Emma Thompson', gender: 'Female', patientId: 'A00033', bloodType: 'O+',
    department: 'Psychiatry', doctor: 'Dr. John Carter', dateOfBirth: '1988-04-25',
    admissionTime: '2026-04-09 09:39', allergy: '',
  );

  Future<void> pump(WidgetTester tester, Patient p, {VoidCallback? onEdit, VoidCallback? onPrint, VoidCallback? onDelete}) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.theme,
        home: Scaffold(body: _PatientCard(
          patient: p,
          onEdit: onEdit ?? () {},
          onPrint: onPrint ?? () {},
          onDelete: onDelete ?? () {},
        )),
      ));

  testWidgets('name renders large and bold (old row style was 13px/w500)', (tester) async {
    await pump(tester, noAllergy);
    final nameText = tester.widget<Text>(find.text('Emma Thompson'));
    expect(nameText.style!.fontSize, greaterThanOrEqualTo(20),
        reason: 'patient name must be noticeably bigger than the old 13px table row');
    expect(nameText.style!.fontWeight, FontWeight.w700);
    print('Name font size: ${nameText.style!.fontSize} (was 13 in the old row layout)');
  });

  testWidgets('all fields are present with readable, enlarged values (old row was 11-12px)', (tester) async {
    await pump(tester, noAllergy);
    for (final expected in ['A00033', 'O+', 'Psychiatry', 'Dr. John Carter', '1988-04-25', '2026-04-09 09:39']) {
      expect(find.text(expected), findsOneWidget, reason: 'field value "$expected" must be visible on the card');
      final t = tester.widget<Text>(find.text(expected));
      expect(t.style!.fontSize, greaterThanOrEqualTo(14),
          reason: '"$expected" must be bigger than the old 11-12px table cell text');
    }
    print('Field value font sizes are all >= 14 (were 11-12 in the old row layout).');
  });

  testWidgets('allergy is highlighted in the warning color when present, muted dash when absent', (tester) async {
    await pump(tester, withAllergy);
    final allergyText = tester.widget<Text>(find.text('Penicillin'));
    expect(allergyText.style!.color, AppColors.allergyColor);
    expect(allergyText.style!.fontWeight, FontWeight.w700);

    await pump(tester, noAllergy);
    expect(find.text('—'), findsOneWidget, reason: 'empty allergy must show a dash, not blank space');
    print('Allergy highlighting confirmed: colored+bold when present, dash when absent.');
  });

  testWidgets('gender badge shows the correct icon and label', (tester) async {
    await pump(tester, noAllergy); // Female
    expect(find.text(S.female), findsOneWidget);
    expect(find.byIcon(Icons.female_rounded), findsOneWidget);
  });

  testWidgets('Edit/Print/Delete are big labeled buttons, each independently tappable', (tester) async {
    var edited = false, printed = false, deleted = false;
    await pump(tester, noAllergy,
        onEdit: () => edited = true, onPrint: () => printed = true, onDelete: () => deleted = true);

    expect(find.text(S.edit), findsOneWidget);
    expect(find.text(S.printBtn), findsOneWidget);
    expect(find.text(S.delete), findsOneWidget);

    // Old buttons were bare 28x28 icon squares; confirm each new button's tap
    // target (padding + icon + label) is comfortably larger than that.
    final editButtonSize = tester.getSize(find.ancestor(
      of: find.text(S.edit), matching: find.byType(GestureDetector),
    ));
    expect(editButtonSize.height, greaterThanOrEqualTo(38),
        reason: 'button tap target must be well above the old 28px icon-only square');
    print('Edit button tap target: ${editButtonSize.width.toStringAsFixed(0)}x${editButtonSize.height.toStringAsFixed(0)} (was 28x28)');

    await tester.tap(find.text(S.edit));
    await tester.tap(find.text(S.printBtn));
    await tester.tap(find.text(S.delete));
    await tester.pump();
    expect(edited, isTrue);
    expect(printed, isTrue);
    expect(deleted, isTrue);
  });

  testWidgets('card keeps the existing glass color theme (no new colors introduced)', (tester) async {
    await pump(tester, noAllergy);
    expect(find.byType(GlassBox), findsOneWidget);
    final nameText = tester.widget<Text>(find.text('Emma Thompson'));
    expect(nameText.style!.color, AppColors.textPrimary, reason: 'must reuse AppColors, not a new hardcoded color');
  });
}

// ─── Verbatim copy of the private card widget tree from patient_list_screen.dart ─

class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onEdit, onPrint, onDelete;
  const _PatientCard({required this.patient, required this.onEdit, required this.onPrint, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = patient;
    final hasAllergy = p.allergy.isNotEmpty && p.allergy.toLowerCase() != 'none';
    return GlassBox(
      blur: 15,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
            ),
            child: Center(child: Text(
              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
              style: TextStyle(color: AppColors.accentBlue, fontSize: 18, fontWeight: FontWeight.w700),
            )),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(p.name,
              style: TextStyle(fontSize: 21, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 10),
          _GenderBadge(gender: p.gender),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 28, runSpacing: 12, children: [
          _Field(label: S.patientId, value: p.patientId),
          _Field(label: S.bloodType, value: p.bloodType, valueColor: AppColors.bloodType, bold: true),
          _Field(label: S.department, value: p.department),
          _Field(label: S.doctor, value: p.doctor),
          _Field(label: S.dateOfBirth, value: p.dateOfBirth),
          _Field(label: S.admissionTimeShort, value: p.admissionTime),
          _Field(
            label: S.allergy,
            value: p.allergy.isEmpty ? '—' : p.allergy,
            valueColor: hasAllergy ? AppColors.allergyColor : null,
            bold: hasAllergy,
          ),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _CardActionBtn(icon: Icons.edit_rounded,   label: S.edit,     color: AppColors.accentBlue,   onTap: onEdit),
          const SizedBox(width: 10),
          _CardActionBtn(icon: Icons.print_rounded,  label: S.printBtn, color: AppColors.successGreen, onTap: onPrint),
          const SizedBox(width: 10),
          _CardActionBtn(icon: Icons.delete_rounded, label: S.delete,   color: AppColors.errorRed,     onTap: onDelete),
        ]),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _Field({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.textMuted, letterSpacing: 0.5,
      )),
      const SizedBox(height: 3),
      Text(value.isEmpty ? '—' : value, style: TextStyle(
        fontSize: 15,
        color: valueColor ?? AppColors.textPrimary,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      )),
    ],
  );
}

class _GenderBadge extends StatelessWidget {
  final String gender;
  const _GenderBadge({required this.gender});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'Male';
    final color = isMale ? AppColors.primaryBlue : const Color(0xFFEC4899);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isMale ? Icons.male_rounded : Icons.female_rounded, size: 18, color: color),
        const SizedBox(width: 4),
        Text(isMale ? S.male : S.female, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
