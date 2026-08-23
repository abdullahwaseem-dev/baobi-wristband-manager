import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/services/print_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';

/// Verifies Chinese text on the wristband actually has glyphs to render.
/// The default PDF base font (Helvetica) has no CJK glyphs, so without a
/// fallback font registered, Chinese characters print as nothing — this is
/// exactly the bug being fixed. We can't rasterize the PDF in this test
/// environment, but we CAN prove: (1) the 17MB CJK font file loads and
/// parses without error — a real risk for large CJK fonts with unusual
/// cmap tables, and (2) a Chinese-heavy patient record produces a
/// meaningfully larger PDF than an all-Latin one, which only happens if the
/// CJK fallback font is actually being subset and embedded for those glyphs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  test('CJK font asset loads and parses without throwing', () async {
    // Exercises the exact rootBundle.load + pw.Font.ttf path PrintService
    // uses. A malformed or unsupported font file would throw here.
    final patient = Patient(name: '陈伟', gender: 'Male', patientId: 'CJK1', bloodType: 'O+');
    final bytes = await PrintService.instance.previewWristband(patient);
    expect(bytes, isNotEmpty);
  });

  test('a Chinese name produces a larger PDF than an equivalent Latin name', () async {
    final latin = Patient(
      name: 'John Smith', gender: 'Male', patientId: 'L1', bloodType: 'O+',
      department: 'Cardiology', doctor: 'Dr. Lee',
    );
    final chinese = Patient(
      name: '陈伟大夫患者姓名', gender: 'Male', patientId: 'C1', bloodType: 'O+',
      department: '心脏科', doctor: '李医生',
    );

    final latinBytes = await PrintService.instance.previewWristband(latin);
    final chineseBytes = await PrintService.instance.previewWristband(chinese);

    expect(chineseBytes.length, greaterThan(latinBytes.length),
        reason: 'Chinese glyphs must pull in embedded font data from the CJK '
            'fallback font — if the fallback wiring is broken, this PDF '
            'would be roughly the same tiny size as the Latin one (and the '
            'Chinese characters would print as nothing).');
  });

  test('mixed Latin + Chinese fields render without error (allergy, dept, doctor)', () async {
    final patient = Patient(
      name: 'Chen Wei 陈伟',
      gender: 'Male',
      patientId: 'MIX1',
      bloodType: 'A+',
      department: '内科',
      doctor: '张医生',
      allergy: '青霉素',
      admissionTime: '2026.07.16 09:00',
    );
    final bytes = await PrintService.instance.previewWristband(patient);
    expect(bytes, isNotEmpty);
  });
}
