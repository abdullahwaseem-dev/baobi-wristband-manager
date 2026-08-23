import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/models/print_record.dart';
import 'package:baobi_wristband/services/db_service.dart';

/// Verifies the "Clear Local Data" action actually wipes both tables — this
/// is the escape hatch for removing demo/test data (e.g. patients pulled in
/// while rehearsing a HIS connection) before handing the app to real users.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // In-memory DB: fully isolated from other test files, no shared-file race.
    await DbService.instance.init(path: inMemoryDatabasePath);
  });

  test('clearAllData removes every patient and print record', () async {
    await DbService.instance.insertPatient(
      Patient(name: 'Test Patient', gender: 'Male', patientId: 'T1', bloodType: 'A+'),
    );
    await DbService.instance.insertPrintRecord(PrintRecord(
      name: 'Test Patient', patientId: 'T1', epcCode: 'EPC-1', tidCode: 'TID-1',
    ));

    expect(await DbService.instance.getPatientCount(), greaterThan(0));
    expect(await DbService.instance.getPrintRecordCount(), greaterThan(0));

    await DbService.instance.clearAllData();

    expect(await DbService.instance.getPatientCount(), 0);
    expect(await DbService.instance.getPrintRecordCount(), 0);
    expect(await DbService.instance.getAllPatients(), isEmpty);
  });
}
