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

/// Drives FirebaseService (push/pull/conflict) against the real local
/// Firestore + Auth emulators — real sockets, real security rules, real
/// optimistic-concurrency preconditions, not mocked.
/// Requires: firebase emulators:start --project demo-baobi-wristband --only auth,firestore
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

const _email = 'sync-test-hospital@example.com';
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
    expect(r.ok, isTrue, reason: 'test setup: sign-in must succeed before any sync test runs');
  });

  test('push then pull round-trips a patient correctly', () async {
    final p = Patient(name: 'Chen Wei', gender: 'Male', patientId: 'SYNC-P1', bloodType: 'O+');
    final pushResult = await _real(() => FirebaseService.instance.pushPatients([p]));
    expect(pushResult.error, isNull);
    expect(pushResult.succeeded.length, 1);
    expect(pushResult.conflicted, isEmpty);
    expect(pushResult.succeeded.first.remoteUpdateTime, isNotNull,
        reason: 'a successful push must record the new remoteUpdateTime for future preconditions');

    final pullResult = await _real(() => FirebaseService.instance.pullPatients());
    expect(pullResult.error, isNull);
    final pulled = pullResult.patients.where((x) => x.patientId == 'SYNC-P1').toList();
    expect(pulled, hasLength(1));
    expect(pulled.single.name, 'Chen Wei');
    expect(pulled.single.dirty, isFalse, reason: 'pulled data is always clean');
  });

  test('re-pushing the same doc with a stale remoteUpdateTime is rejected as a conflict', () async {
    // Simulate "station A pushes, then station B (which saw an OLDER remote
    // version) tries to push a conflicting edit."
    final original = Patient(name: 'Original', gender: 'Male', patientId: 'SYNC-CONFLICT');
    final firstPush = await _real(() => FirebaseService.instance.pushPatients([original]));
    expect(firstPush.succeeded, hasLength(1));
    final staleRemoteUpdateTime = firstPush.succeeded.first.remoteUpdateTime;

    // Station A's edit lands (advances the real remoteUpdateTime).
    final stationA = firstPush.succeeded.first.copyWith(name: 'Station A Edit', dirty: true);
    final aPush = await _real(() => FirebaseService.instance.pushPatients([stationA]));
    expect(aPush.succeeded, hasLength(1));

    // Station B still thinks the OLD (stale) remoteUpdateTime is current.
    final stationB = Patient(
      name: 'Station B Conflicting Edit',
      gender: 'Male',
      patientId: 'SYNC-CONFLICT',
      syncId: original.syncId,
      remoteUpdateTime: staleRemoteUpdateTime,
      dirty: true,
    );
    final bPush = await _real(() => FirebaseService.instance.pushPatients([stationB]));
    expect(bPush.succeeded, isEmpty, reason: 'station B\'s stale write must NOT silently win');
    expect(bPush.conflicted, hasLength(1), reason: 'must be surfaced as a conflict, not dropped silently');

    // Confirm the cloud still has Station A's version, not B's.
    final pull = await _real(() => FirebaseService.instance.pullPatients());
    final winner = pull.patients.firstWhere((x) => x.patientId == 'SYNC-CONFLICT');
    expect(winner.name, 'Station A Edit');
  });

  test('a fresh patient with no remoteUpdateTime pushes without a precondition', () async {
    final p = Patient(name: 'Brand New', gender: 'Female', patientId: 'SYNC-NEW1');
    expect(p.remoteUpdateTime, isNull);
    final result = await _real(() => FirebaseService.instance.pushPatients([p]));
    expect(result.succeeded, hasLength(1));
    expect(result.conflicted, isEmpty);
  });

  test('pushes a larger batch (50 patients) without dropping or duplicating any', () async {
    final batch = List.generate(
      50,
      (i) => Patient(name: 'Bulk Patient $i', gender: 'Male', patientId: 'SYNC-BULK-$i'),
    );
    final result = await _real(() => FirebaseService.instance.pushPatients(batch));
    expect(result.error, isNull);
    expect(result.succeeded, hasLength(50));
    expect(result.conflicted, isEmpty);

    final pull = await _real(() => FirebaseService.instance.pullPatients());
    final bulkIds = pull.patients.map((p) => p.patientId).where((id) => id.startsWith('SYNC-BULK-')).toSet();
    expect(bulkIds, hasLength(50), reason: 'no doc should be dropped or duplicated across the concurrent fan-out');
  });

  test('print records: push, incremental pull picks up only new records', () async {
    // Unique per test RUN, not hardcoded — the emulator persists data across
    // repeated `flutter test` invocations against the same running instance,
    // so fixed timestamps would collide with leftover docs from a previous
    // run and the GREATER_THAN cursor comparison would (correctly!) exclude
    // records at or before an already-seen instant.
    final base = DateTime.now().toUtc();
    final epc1 = 'EPC-${base.microsecondsSinceEpoch}-1';
    final epc2 = 'EPC-${base.microsecondsSinceEpoch}-2';
    await SettingsService.instance.setLastSyncedPrintTime(
        base.subtract(const Duration(days: 1)).toIso8601String());

    final r1 = PrintRecord(
      name: 'Print One', patientId: 'SYNC-PR1', epcCode: epc1, tidCode: 'TID-1',
      printTime: base,
    );
    final push1 = await _real(() => FirebaseService.instance.pushPrintRecords([r1]));
    expect(push1.succeeded.length, 1);

    final pull1 = await _real(() => FirebaseService.instance.pullPrintRecords());
    expect(pull1.error, isNull);
    expect(pull1.records.any((r) => r.epcCode == epc1), isTrue);

    // Second pull with the now-advanced cursor should NOT return r1 again.
    final pull2 = await _real(() => FirebaseService.instance.pullPrintRecords());
    expect(pull2.records.any((r) => r.epcCode == epc1), isFalse,
        reason: 'the incremental cursor must exclude records already pulled');

    // A genuinely new, later record must still come through.
    final r2 = PrintRecord(
      name: 'Print Two', patientId: 'SYNC-PR2', epcCode: epc2, tidCode: 'TID-2',
      printTime: base.add(const Duration(seconds: 5)),
    );
    final push2 = await _real(() => FirebaseService.instance.pushPrintRecords([r2]));
    expect(push2.succeeded.length, 1);
    final pull3 = await _real(() => FirebaseService.instance.pullPrintRecords());
    expect(pull3.records.any((r) => r.epcCode == epc2), isTrue);
  });

  test('not signed in: every call returns a clear error instead of throwing', () async {
    await FirebaseAuthService.instance.signOut();
    final pushResult = await _real(() => FirebaseService.instance.pushPatients(
          [Patient(name: 'X', gender: 'Male', patientId: 'X1')],
        ));
    expect(pushResult.error, contains('Not signed in'));

    final pullResult = await _real(() => FirebaseService.instance.pullPatients());
    expect(pullResult.error, contains('Not signed in'));

    // Re-sign-in for any tests that might run after this in the same file.
    await _real(() => FirebaseAuthService.instance.signIn(_email, _password));
  });
}
