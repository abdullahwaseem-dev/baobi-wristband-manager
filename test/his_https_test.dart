import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baobi_wristband/models/his_config.dart';
import 'package:baobi_wristband/services/his_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';

/// This is the scenario that will actually decide whether the hospital pilot
/// works on the day: many hospital-internal HIS servers run HTTPS with a
/// self-signed or internally-issued certificate. A stock HTTP client refuses
/// those outright with a HandshakeException. We stand up a REAL HTTPS server
/// using a real self-signed certificate (test/fixtures) and prove:
///   1. Without the toggle, the connection is correctly rejected (fails safe).
///   2. With `allowSelfSignedCert: true`, the same server is reachable and
///      patient data parses normally.
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late String base;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    final certPath = 'test/fixtures/test_cert.pem';
    final keyPath  = 'test/fixtures/test_key.pem';
    final context = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);

    server = await HttpServer.bindSecure(InternetAddress.loopbackIPv4, 0, context);
    base = 'https://${server.address.host}:${server.port}';
    server.listen((HttpRequest req) async {
      req.response.headers.contentType = ContentType.json;
      req.response.write(jsonEncode({
        'patientId': 'H1',
        'name': 'HTTPS Patient',
        'gender': 'F',
        'bloodType': 'B+',
      }));
      await req.response.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  test('self-signed HTTPS is REJECTED by default (fails safe)', () async {
    await SettingsService.instance.setHisConfig(
      HisConfig(baseUrl: base, searchEndpoint: '/patient/{id}', allowSelfSignedCert: false),
    );
    final r = await _real(() => HisService.instance.fetchPatientById('H1'));
    expect(r.patient, isNull, reason: 'an untrusted cert must not be silently accepted');
    expect(r.error, isNotNull);
  });

  test('testConnection on untrusted cert explains the fix (mentions the toggle)', () async {
    final r = await _real(() => HisService.instance.testConnection(
          HisConfig(baseUrl: base, listEndpoint: '/patient/1', allowSelfSignedCert: false),
        ));
    expect(r.ok, isFalse);
    expect(r.message.toLowerCase(), contains('self-signed'));
  });

  test('self-signed HTTPS SUCCEEDS once allowSelfSignedCert is enabled', () async {
    await SettingsService.instance.setHisConfig(
      HisConfig(baseUrl: base, searchEndpoint: '/patient/{id}', allowSelfSignedCert: true),
    );
    final r = await _real(() => HisService.instance.fetchPatientById('H1'));
    expect(r.patient, isNotNull);
    expect(r.error, isNull);
    expect(r.patient!.name, 'HTTPS Patient');
    expect(r.patient!.gender, 'Female');
    expect(r.patient!.bloodType, 'B+');
  });

  test('testConnection succeeds over HTTPS once trusted', () async {
    final r = await _real(() => HisService.instance.testConnection(
          HisConfig(baseUrl: base, listEndpoint: '/patient/1', allowSelfSignedCert: true),
        ));
    expect(r.ok, isTrue);
  });
}
