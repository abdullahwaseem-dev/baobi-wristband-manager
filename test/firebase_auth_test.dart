import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baobi_wristband/services/firebase_auth_service.dart';
import 'package:baobi_wristband/services/firebase_env.dart';
import 'package:baobi_wristband/services/settings_service.dart';

/// Drives the real FirebaseAuthService against the real local Firebase Auth
/// Emulator (not a mock) — same philosophy as test/his_service_test.dart.
/// Requires: firebase emulators:start --project demo-baobi-wristband --only auth,firestore
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

const _testEmail = 'auth-test-hospital@example.com';
const _testPassword = 'testpass123';

/// Ensures the shared test account exists in the emulator without failing
/// when a previous test run already created it.
Future<void> _ensureTestUserExists() async {
  final uri = Uri.parse('${FirebaseEnv.identityToolkitBaseUrl}/v1/accounts:signUp?key=${FirebaseEnv.apiKey}');
  final resp = await http.post(uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': _testEmail, 'password': _testPassword, 'returnSecureToken': true}));
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
  });

  tearDown(() async {
    await FirebaseAuthService.instance.signOut();
  });

  test('rejects sign-in with wrong password with a friendly message', () async {
    final r = await _real(() => FirebaseAuthService.instance.signIn(_testEmail, 'wrong-password'));
    expect(r.ok, isFalse);
    expect(r.error, contains('Incorrect email or password'));
    expect(FirebaseAuthService.instance.isSignedIn, isFalse);
  });

  test('signs in successfully and persists the hospital UID', () async {
    final r = await _real(() => FirebaseAuthService.instance.signIn(_testEmail, _testPassword));
    expect(r.ok, isTrue);
    expect(FirebaseAuthService.instance.isSignedIn, isTrue);
    expect(FirebaseAuthService.instance.hospitalUid, isNotEmpty);
    expect(FirebaseAuthService.instance.signedInEmail, _testEmail);
  });

  test('validIdToken returns a usable token after sign-in', () async {
    await _real(() => FirebaseAuthService.instance.signIn(_testEmail, _testPassword));
    final token = await _real(() => FirebaseAuthService.instance.validIdToken());
    expect(token, isNotNull);
    expect(token, isNotEmpty);
  });

  test('validIdToken returns null when not signed in', () async {
    await FirebaseAuthService.instance.signOut();
    final token = await _real(() => FirebaseAuthService.instance.validIdToken());
    expect(token, isNull);
  });

  test('signOut clears the cached refresh token', () async {
    await _real(() => FirebaseAuthService.instance.signIn(_testEmail, _testPassword));
    expect(FirebaseAuthService.instance.isSignedIn, isTrue);
    await FirebaseAuthService.instance.signOut();
    expect(FirebaseAuthService.instance.isSignedIn, isFalse);
  });

  test('empty email/password is rejected without a network call', () async {
    final r = await _real(() => FirebaseAuthService.instance.signIn('', ''));
    expect(r.ok, isFalse);
    expect(r.error, contains('Enter both'));
  });
}
