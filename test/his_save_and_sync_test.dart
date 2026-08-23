import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baobi_wristband/models/his_config.dart';
import 'package:baobi_wristband/services/db_service.dart';
import 'package:baobi_wristband/services/settings_service.dart';
import 'package:baobi_wristband/state/app_state.dart';

/// Proves the exact workflow requested: configure HIS, save, and have every
/// patient from the HIS show up in the Patient List — without a separate
/// manual "sync all" step. Drives AppState.batchSyncFromHis (the same call
/// the HIS dialog's Save button now makes) against a real local HTTP server,
/// then reads the result back out of the real database.
class _RealHttpOverrides extends HttpOverrides {}

Future<T> _real<T>(Future<T> Function() body) =>
    HttpOverrides.runWithHttpOverrides(body, _RealHttpOverrides());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpServer server;
  late String base;
  late AppState appState;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // In-memory DB: fully isolated from other test files, no shared-file race.
    await DbService.instance.init(path: inMemoryDatabasePath);

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((HttpRequest req) async {
      req.response.headers.contentType = ContentType.json;
      if (req.uri.path == '/patients') {
        req.response.write(jsonEncode([
          {'patientId': 'S1', 'name': 'Sync Patient One', 'gender': 'M', 'bloodType': 'O+'},
          {'patientId': 'S2', 'name': 'Sync Patient Two', 'gender': 'F', 'bloodType': 'A-'},
          {'patientId': 'S3', 'name': 'Sync Patient Three', 'gender': 'M', 'bloodType': 'B+'},
        ]));
      } else {
        req.response.statusCode = HttpStatus.notFound;
      }
      await req.response.close();
    });

    appState = AppState();
    // AppState's constructor kicks off async DB loads — let them settle.
    await Future.delayed(const Duration(milliseconds: 100));
  });

  tearDownAll(() async {
    await server.close(force: true);
  });

  test('saving a valid HIS config and syncing populates the Patient List', () async {
    await SettingsService.instance.setHisConfig(
      HisConfig(baseUrl: base, listEndpoint: '/patients'),
    );

    // This is the exact call the HIS dialog's Save button makes.
    final result = await _real(() => appState.batchSyncFromHis(''));
    expect(result.error, isNull);
    expect(result.count, 3);

    // Now confirm it actually landed in the Patient List's data source.
    final patients = await DbService.instance.getAllPatients();
    final names = patients.map((p) => p.name).toSet();
    expect(names, containsAll(['Sync Patient One', 'Sync Patient Two', 'Sync Patient Three']));
  });

  test('re-saving and re-syncing does not duplicate patients', () async {
    final result = await _real(() => appState.batchSyncFromHis(''));
    expect(result.count, 3);

    final patients = await DbService.instance.getAllPatients();
    final s1Count = patients.where((p) => p.patientId == 'S1').length;
    expect(s1Count, 1, reason: 'repeated sync must update in place, not duplicate');
  });

  test('saving with a broken endpoint reports a diagnostic instead of silently syncing 0', () async {
    await SettingsService.instance.setHisConfig(
      HisConfig(baseUrl: base, listEndpoint: '/does-not-exist'),
    );
    final result = await _real(() => appState.batchSyncFromHis(''));
    expect(result.count, 0);
    expect(result.error, isNotNull);
    expect(result.error!.toLowerCase(), contains('404'));
  });
}
