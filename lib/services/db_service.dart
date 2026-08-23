import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/patient.dart';
import '../models/print_record.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  Database? _db;

  /// [path] override is for tests only — pass `inMemoryDatabasePath` (from
  /// sqflite_common_ffi) so each test file gets a fully isolated database
  /// instead of racing other test files on the same physical file on disk.
  Future<void> init({String? path}) async {
    path ??= join(await getDatabasesPath(), 'baobi_wristband.db');
    _db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, v) async {
        await db.execute('''
          CREATE TABLE patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            gender TEXT NOT NULL,
            patient_id TEXT NOT NULL,
            allergy TEXT,
            blood_type TEXT,
            department TEXT,
            doctor TEXT,
            date_of_birth TEXT,
            admission_time TEXT,
            created_at TEXT NOT NULL,
            sync_id TEXT,
            updated_at TEXT,
            dirty INTEGER NOT NULL DEFAULT 0,
            remote_update_time TEXT,
            synced_department TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE print_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            patient_id TEXT NOT NULL,
            gender TEXT,
            date_of_birth TEXT,
            blood_type TEXT,
            allergy TEXT,
            department TEXT,
            doctor TEXT,
            admission_time TEXT,
            epc_code TEXT NOT NULL,
            tid_code TEXT NOT NULL,
            print_time TEXT NOT NULL,
            sync_id TEXT,
            printed_by_uid TEXT
          )
        ''');
        await _createPatientIdIndex(db);
        await _createPrintRecordSyncIdIndex(db);
      },
      onUpgrade: (db, oldV, newV) async {
        // v1 → v2: enforce one record per patient_id. Existing databases can
        // already contain duplicates (older builds never deduped on import/sync),
        // so collapse them — keeping the most recently inserted row — before
        // creating the unique index, otherwise the index creation would fail.
        if (oldV < 2) {
          await db.execute('''
            DELETE FROM patients
            WHERE patient_id <> ''
              AND id NOT IN (
                SELECT MAX(id) FROM patients WHERE patient_id <> '' GROUP BY patient_id
              )
          ''');
          await _createPatientIdIndex(db);
        }
        // v2 → v3: Firebase sync bookkeeping columns. Existing rows are
        // backfilled with a generated sync_id and updated_at = created_at,
        // but left NOT dirty — there's no real hospital data locally yet at
        // this point in the product's life, so nothing needs a forced push;
        // any genuinely new local edit going forward is dirty by default via
        // the Patient/PrintRecord model constructors.
        if (oldV < 3) {
          await db.execute('ALTER TABLE patients ADD COLUMN sync_id TEXT');
          await db.execute('ALTER TABLE patients ADD COLUMN updated_at TEXT');
          await db.execute('ALTER TABLE patients ADD COLUMN dirty INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE patients ADD COLUMN remote_update_time TEXT');
          await db.execute('ALTER TABLE print_records ADD COLUMN sync_id TEXT');
          await _backfillSyncColumns(db);
          await _createPrintRecordSyncIdIndex(db);
        }
        // v3 → v4: department-level Firestore partitioning. synced_department
        // tracks which department slug a patient currently lives under in
        // Firestore, so a later department edit can be detected as a MOVE
        // (delete the old path's doc, don't just overwrite in place) rather
        // than silently leaving a stale copy under the old department —
        // see FirebaseService._pushOnePatient. Left null on upgrade: nothing
        // existing has ever been pushed under the new department-partitioned
        // layout, so there's no prior path to compare against yet — the next
        // push for each row is correctly treated as a first write, not a move.
        // printed_by_uid is a new, always-optional audit field; no backfill
        // needed, existing rows simply have no attributable printer.
        if (oldV < 4) {
          await db.execute('ALTER TABLE patients ADD COLUMN synced_department TEXT');
          await db.execute('ALTER TABLE print_records ADD COLUMN printed_by_uid TEXT');
        }
      },
    );
  }

  /// Partial unique index on print_records.sync_id: lets the Firestore pull
  /// path insert with ConflictAlgorithm.ignore and get "insert once, skip on
  /// repeat" for free, so pulling the same record on repeated sync ticks
  /// never duplicates it locally.
  Future<void> _createPrintRecordSyncIdIndex(Database db) => db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_print_records_sync_id "
        "ON print_records(sync_id) WHERE sync_id IS NOT NULL",
      );

  /// Generates sync_id (and updated_at, for patients) for rows that predate
  /// the v3 migration. Uses the same lightweight id scheme as the Dart
  /// models (timestamp + counter) rather than pulling in `uuid` here.
  Future<void> _backfillSyncColumns(Database db) async {
    var counter = 0;
    String newId() {
      counter++;
      return '${DateTime.now().microsecondsSinceEpoch}-$counter';
    }

    final patientRows = await db.query('patients', columns: ['id', 'created_at'], where: 'sync_id IS NULL');
    final patientBatch = db.batch();
    for (final row in patientRows) {
      patientBatch.update(
        'patients',
        {'sync_id': newId(), 'updated_at': row['created_at']},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
    await patientBatch.commit(noResult: true);

    final printRows = await db.query('print_records', columns: ['id'], where: 'sync_id IS NULL');
    final printBatch = db.batch();
    for (final row in printRows) {
      printBatch.update('print_records', {'sync_id': newId()}, where: 'id = ?', whereArgs: [row['id']]);
    }
    await printBatch.commit(noResult: true);
  }

  /// Partial unique index: enforces one row per non-empty patient_id while still
  /// allowing multiple blank-ID rows (e.g. spreadsheet rows imported without an
  /// ID column). Combined with ConflictAlgorithm.replace this makes re-importing
  /// or re-syncing the same patient update-in-place instead of duplicating.
  Future<void> _createPatientIdIndex(Database db) => db.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS idx_patients_patient_id "
        "ON patients(patient_id) WHERE patient_id <> ''",
      );

  Database get db => _db!;

  // ─── Patients ─────────────────────────────────────────────────────────────

  Future<int> insertPatient(Patient p) =>
      db.insert('patients', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<int> updatePatient(Patient p) =>
      db.update('patients', p.toMap(), where: 'id = ?', whereArgs: [p.id]);

  Future<int> deletePatient(int id) =>
      db.delete('patients', where: 'id = ?', whereArgs: [id]);

  Future<List<Patient>> getPatients({String? search, int? limit, int? offset}) async {
    final where = (search != null && search.isNotEmpty)
        ? 'name LIKE ? OR patient_id LIKE ?'
        : null;
    final args = (search != null && search.isNotEmpty)
        ? ['%$search%', '%$search%']
        : null;
    final rows = await db.query(
      'patients',
      where: where,
      whereArgs: args,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(Patient.fromMap).toList();
  }

  Future<int> getPatientCount({String? search}) async {
    final where = (search != null && search.isNotEmpty)
        ? 'name LIKE ? OR patient_id LIKE ?'
        : null;
    final args = (search != null && search.isNotEmpty)
        ? ['%$search%', '%$search%']
        : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM patients${where != null ? " WHERE $where" : ""}',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<Patient?> getPatientByPatientId(String patientId) async {
    final rows = await db.query('patients', where: 'patient_id = ?', whereArgs: [patientId]);
    return rows.isEmpty ? null : Patient.fromMap(rows.first);
  }

  Future<List<Patient>> getAllPatients() => getPatients();

  /// Bulk upsert used by HIS batch sync, Excel import, and Firestore pull.
  /// Rows whose patient_id currently has unsynced local edits (dirty=1) are
  /// skipped rather than overwritten — otherwise a HIS re-sync or cloud pull
  /// arriving mid-shift would silently discard an offline edit that hasn't
  /// been pushed yet. Returns the count actually written, for status messages.
  Future<int> batchInsertPatients(List<Patient> patients) async {
    if (patients.isEmpty) return 0;

    final ids = patients.map((p) => p.patientId).where((id) => id.isNotEmpty).toSet();
    var dirtyIds = const <String>{};
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(',');
      final dirtyRows = await db.query(
        'patients',
        columns: ['patient_id'],
        where: 'dirty = 1 AND patient_id IN ($placeholders)',
        whereArgs: ids.toList(),
      );
      dirtyIds = dirtyRows.map((r) => r['patient_id'] as String).toSet();
    }

    final toWrite = patients.where((p) => p.patientId.isEmpty || !dirtyIds.contains(p.patientId)).toList();
    final batch = db.batch();
    for (final p in toWrite) {
      batch.insert('patients', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    return toWrite.length;
  }

  /// Every patient with a local edit not yet pushed to Firestore.
  Future<List<Patient>> getDirtyPatients() async {
    final rows = await db.query('patients', where: 'dirty = 1');
    return rows.map(Patient.fromMap).toList();
  }

  // ─── Print Records ─────────────────────────────────────────────────────────

  /// Ignores (rather than replaces) on a sync_id collision — a genuinely new
  /// local print (fresh sync_id) always inserts; a record arriving twice via
  /// repeated Firestore pulls is silently skipped rather than duplicated.
  Future<int> insertPrintRecord(PrintRecord r) =>
      db.insert('print_records', r.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);

  /// Print records not yet pushed to Firestore, in insertion order. Print
  /// records are append-only (never edited), so the local autoincrement id
  /// is a safe, simple monotonic "needs push" cursor — no separate dirty
  /// flag needed, unlike patients.
  Future<List<PrintRecord>> getPrintRecordsSinceId(int afterId) async {
    final rows = await db.query(
      'print_records',
      where: 'id > ?',
      whereArgs: [afterId],
      orderBy: 'id ASC',
    );
    return rows.map(PrintRecord.fromMap).toList();
  }

  Future<List<PrintRecord>> getPrintRecords({String? search, int? limit, int? offset}) async {
    final where = (search != null && search.isNotEmpty)
        ? 'name LIKE ? OR patient_id LIKE ?'
        : null;
    final args = (search != null && search.isNotEmpty)
        ? ['%$search%', '%$search%']
        : null;
    final rows = await db.query(
      'print_records',
      where: where,
      whereArgs: args,
      orderBy: 'print_time DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map(PrintRecord.fromMap).toList();
  }

  Future<int> getPrintRecordCount({String? search}) async {
    final where = (search != null && search.isNotEmpty)
        ? 'name LIKE ? OR patient_id LIKE ?'
        : null;
    final args = (search != null && search.isNotEmpty)
        ? ['%$search%', '%$search%']
        : null;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM print_records${where != null ? " WHERE $where" : ""}',
      args,
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<List<PrintRecord>> getRecentPrintRecords({int limit = 5}) async {
    final rows = await db.query('print_records', orderBy: 'print_time DESC', limit: limit);
    return rows.map(PrintRecord.fromMap).toList();
  }

  // ─── Maintenance ────────────────────────────────────────────────────────────

  /// Wipes every patient and print record. Used by the "Clear Local Data"
  /// admin action — e.g. to remove demo/test data (such as records pulled in
  /// while rehearsing a HIS connection) before handing the app to real users.
  Future<void> clearAllData() async {
    await db.delete('patients');
    await db.delete('print_records');
  }
}
