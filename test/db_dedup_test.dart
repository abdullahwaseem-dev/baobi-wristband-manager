import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/services/db_service.dart';

/// Verifies the patient de-duplication guarantee: re-importing or re-syncing the
/// same patient_id must update in place, never create a duplicate row — while
/// blank-ID rows (spreadsheet rows without an ID) are still allowed to coexist.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // In-memory DB: fully isolated from other test files, no shared-file race.
    await DbService.instance.init(path: inMemoryDatabasePath);
  });

  Patient patient(String id, String name) =>
      Patient(name: name, gender: 'Male', patientId: id, bloodType: 'A+');

  test('re-inserting the same patient_id replaces instead of duplicating', () async {
    await DbService.instance.insertPatient(patient('P100', 'First Name'));
    await DbService.instance.insertPatient(patient('P100', 'Updated Name'));

    final rows = await DbService.instance.getPatients(search: 'P100');
    expect(rows.length, 1, reason: 'duplicate patient_id must collapse to one row');
    expect(rows.single.name, 'Updated Name', reason: 'latest write should win');
  });

  test('batch re-sync of the same patients does not create duplicates', () async {
    final batch = [patient('S1', 'Sync One'), patient('S2', 'Sync Two')];
    await DbService.instance.batchInsertPatients(batch);
    await DbService.instance.batchInsertPatients(batch); // simulate a second sync

    final s1 = await DbService.instance.getPatients(search: 'S1');
    final s2 = await DbService.instance.getPatients(search: 'S2');
    expect(s1.length, 1);
    expect(s2.length, 1);
  });

  test('blank-ID rows are allowed to coexist (partial unique index)', () async {
    await DbService.instance.insertPatient(patient('', 'No ID A'));
    await DbService.instance.insertPatient(patient('', 'No ID B'));

    final all = await DbService.instance.getAllPatients();
    final blanks = all.where((p) => p.patientId.isEmpty).toList();
    expect(blanks.length, greaterThanOrEqualTo(2),
        reason: 'blank patient_id must not be de-duplicated');
  });
}
