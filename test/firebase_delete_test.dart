import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/models/print_record.dart';
import 'package:baobi_wristband/services/firebase_auth_service.dart';
import 'package:baobi_wristband/services/firebase_env.dart';
import 'package:baobi_wristband/services/firebase_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';

class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

const _email = 'delete-test-hospital@example.com';
const _password = 'testpass123';

Future<void> _ensureTestUserExists() async {
  final uri = Uri.parse('${FirebaseEnv.identityToolkitBaseUrl}/v1/accounts:signUp?key=${FirebaseEnv.apiKey}');
  final resp = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': _email, 'password': _password, 'returnSecureToken': true}));
  if (resp.statusCode == 200) return;
  final body = json.decode(resp.body) as Map<String, dynamic>;
  final code = (body['error']?['message'] as String?) ?? '';
  if (code != 'EMAIL_EXISTS') {
    throw StateError('Could not seed test account: ${resp.body}');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    FirebaseEnv.useEmulator(projectId: 'demo-baobi-wristband');
    await _real(_ensureTestUserExists);
    final r = await _real(() => FirebaseAuthService.instance.signIn(_email, _password));
    expect(r.ok, isTrue);
  });

  test('deleteAllHospitalData wipes both collections and pull confirms empty', () async {
    // Seed some data in both collections.
    final patients = List.generate(5, (i) => Patient(name: 'Del $i', gender: 'Male', patientId: 'DEL-P$i'));
    await _real(() => FirebaseService.instance.pushPatients(patients));
    final records = List.generate(
      3,
      (i) => PrintRecord(name: 'Del R$i', patientId: 'DEL-P$i', epcCode: 'DEL-EPC-$i', tidCode: 'DEL-TID-$i'),
    );
    await _real(() => FirebaseService.instance.pushPrintRecords(records));

    // Confirm seeded data is actually there first.
    final before = await _real(() => FirebaseService.instance.pullPatients());
    expect(before.patients.where((p) => p.patientId.startsWith('DEL-P')).length, 5);

    final result = await _real(() => FirebaseService.instance.deleteAllHospitalData());
    expect(result.error, isNull);
    expect(result.deleted, greaterThanOrEqualTo(8)); // 5 patients + 3 print records

    final after = await _real(() => FirebaseService.instance.pullPatients());
    expect(after.patients.where((p) => p.patientId.startsWith('DEL-P')), isEmpty);
  });

  test('not signed in: returns a clear error instead of throwing', () async {
    await FirebaseAuthService.instance.signOut();
    final result = await _real(() => FirebaseService.instance.deleteAllHospitalData());
    expect(result.error, contains('Not signed in'));
  });
}
