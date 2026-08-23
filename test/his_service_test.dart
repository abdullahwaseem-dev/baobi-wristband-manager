import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baobi_wristband/models/his_config.dart';
import 'package:baobi_wristband/services/his_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';

/// Flutter's test binding stubs every HTTP request with a 400 so tests can't
/// hit the network. This override restores the real HttpClient so we can drive
/// HisService against a genuine local server.
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

/// Drives the real HisService against a real local HTTP server so we exercise
/// the actual socket / auth / parsing code paths a hospital HIS will hit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late String base;
  String? lastAuthHeader;
  String? lastPath;
  Map<String, String> lastQuery = const {};

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((HttpRequest req) async {
      lastAuthHeader = req.headers.value('authorization');
      lastPath = req.uri.path;
      lastQuery = req.uri.queryParameters;
      final path = req.uri.path;
      final res = req.response;
      res.headers.contentType = ContentType.json;

      // Flat top-level JSON object
      if (path == '/api/patient/123') {
        res.write(jsonEncode({
          'patientId': '123',
          'name': 'John Doe',
          'gender': 'M',
          'bloodType': 'O+',
          'department': 'Cardiology',
          'doctor': 'Dr Li',
          'allergy': 'Penicillin',
          'dateOfBirth': '1990.01.01',
          'admissionTime': '2026.07.04 10:00',
        }));
      }
      // Nested JSON wrapped under "data", needs dot-notation field mapping
      else if (path == '/api/nested/456') {
        res.write(jsonEncode({
          'data': {
            'mrn': '456',
            'demographics': {'fullName': 'Jane Roe', 'sex': 'female', 'blood': 'A-'},
          },
        }));
      }
      // "Not found" that still answers HTTP 200 with an empty object
      else if (path == '/api/empty/789') {
        res.write('{}');
      }
      // Hard 404 not found
      else if (path == '/api/missing/000') {
        res.statusCode = HttpStatus.notFound;
      }
      // Requires auth
      else if (path == '/api/secure/1') {
        if (lastAuthHeader == null) {
          res.statusCode = HttpStatus.unauthorized;
        } else {
          res.write(jsonEncode({'patientId': '1', 'name': 'Secure Sam'}));
        }
      }
      // List endpoint for batch sync + test connection
      else if (path == '/api/patients') {
        res.write(jsonEncode({
          'data': [
            {'patientId': 'A1', 'name': 'Alice'},
            {'patientId': 'B2', 'name': 'Bob'},
            {}, // empty row — must be dropped
          ],
        }));
      }
      // Real-world case: single-patient and list responses use DIFFERENT
      // envelope keys on the same API (single: "result", list: "result.items").
      else if (path == '/api/dualenvelope/patient/1') {
        res.write(jsonEncode({
          'result': {'patientId': '1', 'name': 'Envelope Patient'},
        }));
      } else if (path == '/api/dualenvelope/patients') {
        res.write(jsonEncode({
          'result': {
            'items': [
              {'patientId': 'E1', 'name': 'Envelope One'},
              {'patientId': 'E2', 'name': 'Envelope Two'},
            ],
          },
        }));
      } else {
        res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  Future<void> setCfg(HisConfig cfg) => SettingsService.instance.setHisConfig(cfg);

  test('fetches a flat patient and normalises gender', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', searchEndpoint: '/patient/{id}'));
    final r = await _real(() => HisService.instance.fetchPatientById('123'));
    expect(r.patient, isNotNull);
    expect(r.error, isNull);
    expect(r.patient!.name, 'John Doe');
    expect(r.patient!.gender, 'Male'); // "M" normalised
    expect(r.patient!.bloodType, 'O+');
    expect(r.patient!.allergy, 'Penicillin');
    expect(r.patient!.department, 'Cardiology');
  });

  test('normalises URL: trailing slash on base + no leading slash on endpoint', () async {
    await setCfg(HisConfig(baseUrl: '$base/api/', searchEndpoint: 'patient/{id}'));
    final r = await _real(() => HisService.instance.fetchPatientById('123'));
    expect(r.patient, isNotNull);
    expect(lastPath, '/api/patient/123'); // no double slash, correct path
  });

  test('supports nested dot-notation field mapping under a response array key', () async {
    await setCfg(HisConfig(
      baseUrl: '$base/api',
      searchEndpoint: '/nested/{id}',
      searchResponseKey: 'data',
      fPatientId: 'mrn',
      fName: 'demographics.fullName',
      fGender: 'demographics.sex',
      fBloodType: 'demographics.blood',
    ));
    final r = await _real(() => HisService.instance.fetchPatientById('456'));
    expect(r.patient, isNotNull);
    expect(r.patient!.name, 'Jane Roe');
    expect(r.patient!.gender, 'Female');
    expect(r.patient!.bloodType, 'A-');
    expect(r.patient!.patientId, '456');
  });

  test('returns a diagnostic (not a blank patient) for an empty 200 object', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', searchEndpoint: '/empty/{id}'));
    final r = await _real(() => HisService.instance.fetchPatientById('789'));
    expect(r.patient, isNull, reason: 'empty 200 must be treated as not-found');
    expect(r.error, isNotNull);
    expect(r.error!.toLowerCase(), contains('no patient found'));
  });

  test('returns a diagnostic explaining the 404', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', searchEndpoint: '/missing/{id}'));
    final r = await _real(() => HisService.instance.fetchPatientById('000'));
    expect(r.patient, isNull);
    expect(r.error, contains('404'));
  });

  test('sends Basic auth header and reads a secured record', () async {
    await setCfg(HisConfig(
      baseUrl: '$base/api',
      searchEndpoint: '/secure/{id}',
      authType: 'basic',
      username: 'admin',
      password: 's3cret',
    ));
    final r = await _real(() => HisService.instance.fetchPatientById('1'));
    expect(r.patient, isNotNull);
    expect(r.patient!.name, 'Secure Sam');
    final expected = 'Basic ${base64Encode(utf8.encode('admin:s3cret'))}';
    expect(lastAuthHeader, expected);
  });

  test('single-patient and list envelopes can use independent response keys', () async {
    // Regression test: a hospital API wraps the single-patient response under
    // "result" but the list response under "result.items" — the SAME config
    // must satisfy both endpoints since searchResponseKey and listArrayKey are
    // now independent fields (previously a single shared field made this
    // combination impossible to configure).
    await setCfg(HisConfig(
      baseUrl: '$base/api',
      searchEndpoint: '/dualenvelope/patient/{id}',
      searchResponseKey: 'result',
      listEndpoint: '/dualenvelope/patients',
      listArrayKey: 'result.items',
    ));
    final single = await _real(() => HisService.instance.fetchPatientById('1'));
    expect(single.patient, isNotNull);
    expect(single.patient!.name, 'Envelope Patient');

    final list = await _real(() => HisService.instance.batchSync(''));
    expect(list.error, isNull);
    expect(list.patients.length, 2);
    expect(list.patients.map((p) => p.name), containsAll(['Envelope One', 'Envelope Two']));
  });

  test('the configured Department is sent as its own request parameter', () async {
    await setCfg(HisConfig(
      baseUrl: '$base/api',
      searchEndpoint: '/patient/{id}',
      department: 'Cardiology',
    ));
    final r = await _real(() => HisService.instance.fetchPatientById('123'));
    expect(r.patient, isNotNull);
    expect(lastQuery['department'], 'Cardiology');
  });

  test('batchSync sends both the configured Department and a ward filter together', () async {
    await setCfg(HisConfig(
      baseUrl: '$base/api',
      listEndpoint: '/patients',
      listArrayKey: 'data',
      department: 'Cardiology',
    ));
    final r = await _real(() => HisService.instance.batchSync('ICU'));
    expect(r.error, isNull);
    expect(lastQuery['department'], 'Cardiology');
    expect(lastQuery['ward'], 'ICU');
  });

  test('an unset Department omits the request parameter entirely', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', searchEndpoint: '/patient/{id}'));
    final r = await _real(() => HisService.instance.fetchPatientById('123'));
    expect(r.patient, isNotNull);
    expect(lastQuery.containsKey('department'), isFalse);
  });

  test('batchSync parses a wrapped list and drops empty rows', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', listEndpoint: '/patients', listArrayKey: 'data'));
    final r = await _real(() => HisService.instance.batchSync(''));
    expect(r.error, isNull);
    expect(r.patients.length, 2);
    expect(r.patients.map((p) => p.name), containsAll(['Alice', 'Bob']));
  });

  test('batchSync reports a diagnostic when the array key is wrong', () async {
    await setCfg(HisConfig(baseUrl: '$base/api', listEndpoint: '/patients', listArrayKey: 'wrongKey'));
    final r = await _real(() => HisService.instance.batchSync(''));
    expect(r.patients, isEmpty);
    expect(r.error, isNotNull);
  });

  test('testConnection: 200 = ok', () async {
    final r = await _real(() => HisService.instance
        .testConnection(HisConfig(baseUrl: '$base/api', listEndpoint: '/patients')));
    expect(r.ok, isTrue);
  });

  test('testConnection: 404 = reachable but wrong endpoint (not ok)', () async {
    final r = await _real(() => HisService.instance
        .testConnection(HisConfig(baseUrl: '$base/api', listEndpoint: '/nope')));
    expect(r.ok, isFalse);
    expect(r.message, contains('404'));
  });

  test('testConnection: unreachable host fails gracefully', () async {
    final r = await _real(() => HisService.instance.testConnection(
          const HisConfig(baseUrl: 'http://127.0.0.1:1', listEndpoint: '/x'),
        ));
    expect(r.ok, isFalse);
    expect(r.message.toLowerCase(), anyOf(contains('reach'), contains('error'), contains('timed out')));
  });

  test('empty server URL is rejected', () async {
    final r = await HisService.instance.testConnection(const HisConfig());
    expect(r.ok, isFalse);
  });
}
