// ignore_for_file: avoid_print
// Manual, REAL-BACKEND verification of the "Sync HIS" flow.
//
// Unlike everything under test/ (which targets the local Firebase Emulator
// and is safe for anyone to run anytime), this drives AppState.batchSyncFromHis
// — the exact method the HIS dialog's Save button calls — against a LIVE mock
// HIS server AND the real production Firebase project (baobi-8eb0c). It costs
// a handful of real Blaze reads/writes and requires network access, so it
// deliberately lives in tool/ (not test/) and is never picked up by a bare
// `flutter test`.
//
// Run with:
//   1. dart run tool/mock_his_server.dart        (separate terminal, leave running)
//   2. flutter test tool/verify_his_firebase_sync.dart
//
// The two accounts below are disposable sandboxed test accounts created for
// exactly this kind of verification. Not real credentials to protect. Each
// one's own Firebase Auth UID is used directly as its Firestore tenant key
// (see firestore.rules) — a plain accounts:signUp is all either one needs
// before this script can sign in as it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baobi_wristband/models/his_config.dart';
import 'package:baobi_wristband/services/db_service.dart';
import 'package:baobi_wristband/services/firebase_auth_service.dart';
import 'package:baobi_wristband/services/firebase_env.dart';
import 'package:baobi_wristband/services/firebase_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';
import 'package:baobi_wristband/state/app_state.dart';

class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

const _hospital1Email = 'demo-hospital-1@example.com';
const _hospital1Password = 'MI4a0ICvAcqMxtGwAa1!';
const _hospital2Email = 'demo-hospital-2@example.com';
const _hospital2Password = 'X8ZavxHyfU8SmaTnAa1!';

const _mockHisBase = 'http://localhost:9090';

const _expectedNames = {
  'P1001': 'Chen Wei',
  'P1002': 'Fatima Al-Sayed',
  'P1003': 'John Smith',
  'P1004': 'Aiko Tanaka',
  'P1005': 'Ahmed Karim',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppState appState;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DbService.instance.init(path: inMemoryDatabasePath);

    print('Target Firebase project: ${FirebaseEnv.projectId} (REAL production, not emulator)');

    final signIn = await _real(() => FirebaseAuthService.instance.signIn(_hospital1Email, _hospital1Password));
    expect(signIn.ok, isTrue, reason: 'sign-in to real Firebase must succeed: ${signIn.error}');
    print('Signed in as $_hospital1Email — hospital UID ${FirebaseAuthService.instance.hospitalUid}');

    appState = AppState();
    await Future.delayed(const Duration(milliseconds: 150));
  });

  tearDownAll(() {
    appState.dispose();
  });

  test('mock HIS server is reachable and serving 5 patients', () async {
    final resp = await _real(() => http.get(Uri.parse('$_mockHisBase/easy/patients')));
    expect(resp.statusCode, 200);
    final list = json.decode(resp.body) as List;
    expect(list.length, 5);
  });

  test('Sync HIS (default field mapping) pulls all 5 and pushes them to real Firebase', () async {
    await SettingsService.instance.setHisConfig(const HisConfig(baseUrl: '$_mockHisBase/easy'));

    final result = await _real(() => appState.batchSyncFromHis(''));
    expect(result.error, isNull, reason: 'batchSyncFromHis reported an error: ${result.error}');
    expect(result.count, 5);

    for (final entry in _expectedNames.entries) {
      final rows = await DbService.instance.getPatients(search: entry.key);
      final row = rows.where((p) => p.patientId == entry.key);
      expect(row, isNotEmpty, reason: 'patient ${entry.key} missing locally after HIS sync');
      expect(row.first.name, entry.value);
      expect(row.first.dirty, isFalse, reason: 'a patient pushed and acknowledged by Firestore must be clean');
      expect(row.first.remoteUpdateTime, isNotNull, reason: 'must carry the Firestore updateTime once pushed');
    }

    expect(appState.cloudSyncError, isNull);
    expect(appState.lastCloudSyncAt, isNotNull);
    expect(await DbService.instance.getDirtyPatients(), isEmpty,
        reason: 'nothing should be left pending push after a clean sync');
    print('Local DB after sync: all 5 patients present, clean, remoteUpdateTime set.');
  });

  test('wiping the local cache and pulling fresh from Firestore ALONE still returns all 5', () async {
    await DbService.instance.clearAllData();
    expect(await DbService.instance.getPatients(), isEmpty);

    final pull = await _real(() => FirebaseService.instance.pullPatients());
    expect(pull.error, isNull);
    expect(pull.patients.length, 5);
    for (final entry in _expectedNames.entries) {
      final match = pull.patients.where((p) => p.patientId == entry.key);
      expect(match, isNotEmpty, reason: '${entry.key} not found in a fresh pull straight from Firestore');
      expect(match.first.name, entry.value);
    }
    print('Fresh pull from Firestore (no local cache involved): all 5 patients confirmed present.');

    await DbService.instance.batchInsertPatients(pull.patients); // restore for later tests
  });

  test('raw Firestore REST GET shows the exact stored document', () async {
    final token = await _real(() => FirebaseAuthService.instance.validIdToken());
    expect(token, isNotNull);
    final path = 'hospitals/${FirebaseAuthService.instance.hospitalUid}/patients/P1001';
    final uri = Uri.parse(
      '${FirebaseEnv.firestoreBaseUrl}/v1/projects/${FirebaseEnv.projectId}/databases/(default)/documents/$path',
    );
    final resp = await _real(() => http.get(uri, headers: {'Authorization': 'Bearer $token'}));
    expect(resp.statusCode, 200);
    print('Raw Firestore document at $path:');
    print(resp.body);
    expect(resp.body, contains('Chen Wei'));
    expect(resp.body, contains('Cardiology'));
  });

  test('re-syncing via the awkward/nested/auth-gated HIS scenario updates the SAME 5 docs, no duplicates', () async {
    await SettingsService.instance.setHisConfig(const HisConfig(
      baseUrl: '$_mockHisBase/hospital',
      authType: 'bearer',
      bearerToken: 'demo-secret-token',
      searchResponseKey: 'result',
      listArrayKey: 'result.items',
      fPatientId: 'mrn',
      fName: 'demographics.fullName',
      fGender: 'demographics.sexCode',
      fDateOfBirth: 'demographics.birthDate',
      fBloodType: 'demographics.bloodGroup',
      fDepartment: 'encounter.ward',
      fDoctor: 'encounter.attendingPhysician',
      fAllergy: 'allergies',
      fAdmissionTime: 'encounter.admittedAt',
    ));

    final result = await _real(() => appState.batchSyncFromHis(''));
    expect(result.error, isNull, reason: 'batchSyncFromHis reported an error: ${result.error}');
    expect(result.count, 5);

    final pull = await _real(() => FirebaseService.instance.pullPatients());
    expect(pull.error, isNull);
    expect(pull.patients.length, 5, reason: 'must upsert onto the same 5 docs, not create 10');
    print('Re-sync via a differently-shaped HIS API still converges on the same 5 Firestore docs.');
  });

  test('the OTHER hospital account cannot see any of this data (tenant isolation holds)', () async {
    final signIn2 = await _real(() => FirebaseAuthService.instance.signIn(_hospital2Email, _hospital2Password));
    expect(signIn2.ok, isTrue, reason: 'sign-in as hospital-2 must succeed: ${signIn2.error}');

    final pull = await _real(() => FirebaseService.instance.pullPatients());
    expect(pull.error, isNull);
    expect(pull.patients, isEmpty, reason: "hospital-2 must not see hospital-1's HIS-synced roster");
    print('Confirmed: demo-hospital-2 sees ${pull.patients.length} patients (must be 0) — isolation holds.');

    // Leave the session signed back in as hospital-1 for anyone re-running this.
    final resignIn = await _real(() => FirebaseAuthService.instance.signIn(_hospital1Email, _hospital1Password));
    expect(resignIn.ok, isTrue);
  });
}
