import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/services/db_service.dart';
import 'package:baobi_wristband/services/firebase_auth_service.dart';
import 'package:baobi_wristband/services/firebase_env.dart';
import 'package:baobi_wristband/services/settings_service.dart';
import 'package:baobi_wristband/state/app_state.dart';

/// Drives the full AppState.syncWithFirebase() orchestration — push dirty
/// patients, handle conflicts, pull the merged roster — through the real
/// AppState against the real emulator, not just the underlying FirebaseService
/// directly (that's covered separately in firebase_sync_test.dart).
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

const _email = 'appstate-sync-test@example.com';
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

  late AppState appState;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DbService.instance.init(path: inMemoryDatabasePath);

    FirebaseEnv.useEmulator(projectId: 'demo-baobi-wristband');
    await _real(_ensureTestUserExists);
    final signIn = await _real(() => FirebaseAuthService.instance.signIn(_email, _password));
    expect(signIn.ok, isTrue, reason: 'test setup: sign-in must succeed before any test runs');

    appState = AppState();
    await Future.delayed(const Duration(milliseconds: 100)); // let constructor's async loads settle
  });

  tearDownAll(() {
    appState.dispose(); // cancels the periodic sync timer
  });

  test('a locally-added (dirty) patient gets pushed to Firestore on sync', () async {
    final patient = Patient(name: 'Orchestration Test', gender: 'Male', patientId: 'APPSTATE-P1', bloodType: 'B+');
    await appState.addPatient(patient); // goes through the normal Add-dialog path -> dirty:true

    await _real(() => appState.syncWithFirebase());

    final row = (await DbService.instance.getPatients(search: 'APPSTATE-P1')).single;
    expect(row.dirty, isFalse, reason: 'a successfully pushed patient must be marked clean locally');
    expect(row.remoteUpdateTime, isNotNull);
    expect(appState.cloudSyncError, isNull);
    expect(appState.lastCloudSyncAt, isNotNull);
  });

  test('syncWithFirebase is a no-op (no crash, no error) when not signed in', () async {
    await FirebaseAuthService.instance.signOut();
    await appState.syncWithFirebase(); // must not throw
    expect(appState.isCloudSyncing, isFalse);
    // Re-sign-in for any tests after this one in the same file.
    await _real(() => FirebaseAuthService.instance.signIn(_email, _password));
  });

  test('overlapping sync calls self-throttle instead of racing', () async {
    final patient = Patient(name: 'Throttle Test', gender: 'Female', patientId: 'APPSTATE-P2');
    await appState.addPatient(patient);

    // Fire two syncs concurrently without awaiting the first — the second
    // must see isCloudSyncing and return immediately rather than running a
    // second overlapping push/pull cycle.
    final f1 = _real(() => appState.syncWithFirebase());
    final f2 = _real(() => appState.syncWithFirebase());
    await Future.wait([f1, f2]);

    final row = (await DbService.instance.getPatients(search: 'APPSTATE-P2')).single;
    expect(row.dirty, isFalse); // still ends up synced by the one that actually ran
  });
}
