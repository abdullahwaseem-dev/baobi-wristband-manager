import '../models/patient.dart';
import '../models/print_record.dart';

/// Dart <-> Firestore REST API typed-value (de)serialization.
///
/// Firestore's REST API wraps every field value in a type envelope, e.g.
/// `{"stringValue": "..."}` or `{"integerValue": "5"}` (note: as a STRING,
/// not a bare JSON number — a real and easy-to-miss gotcha). This is kept
/// as a small set of pure functions (no HTTP dependency) so it's cheap and
/// fast to unit test in isolation from any network/emulator.
class FirestoreCodec {
  FirestoreCodec._();

  // ─── Primitive value encode/decode ──────────────────────────────────────────

  static Map<String, dynamic> _val(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': v.toString()};
    // Firestore REST requires RFC3339 UTC timestamps. A bare local-time
    // DateTime.now().toIso8601String() has no Z/offset and gets rejected
    // with a 400 — convert only here, at the serialization boundary; the
    // local SQLite storage/display format is untouched.
    if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
    return {'stringValue': v.toString()};
  }

  static dynamic _decode(Map<String, dynamic>? fieldValue) {
    if (fieldValue == null) return null;
    if (fieldValue.containsKey('stringValue')) return fieldValue['stringValue'] as String?;
    if (fieldValue.containsKey('integerValue')) {
      return int.tryParse(fieldValue['integerValue']?.toString() ?? '');
    }
    if (fieldValue.containsKey('booleanValue')) return fieldValue['booleanValue'] as bool?;
    if (fieldValue.containsKey('timestampValue')) {
      return DateTime.tryParse(fieldValue['timestampValue'] as String? ?? '');
    }
    return null;
  }

  static String _str(Map<String, dynamic> fields, String key) {
    final raw = fields[key];
    if (raw is! Map<String, dynamic>) return '';
    return (_decode(raw) as String?) ?? '';
  }

  static DateTime _dateTime(Map<String, dynamic> fields, String key) {
    final raw = fields[key];
    if (raw is! Map<String, dynamic>) return DateTime.now();
    return (_decode(raw) as DateTime?) ?? DateTime.now();
  }

  // ─── Document ID ─────────────────────────────────────────────────────────
  // Firestore doc IDs can't contain "/", can't be "." or "..", and can't
  // match ^__.*__$ (reserved). Real-world patient IDs never hit these, but
  // sanitize defensively rather than let a PATCH silently 400.

  static String sanitizeDocId(String raw) {
    var id = raw.replaceAll('/', '_').trim();
    if (id.isEmpty || id == '.' || id == '..' || RegExp(r'^__.*__$').hasMatch(id)) {
      id = 'doc-${DateTime.now().microsecondsSinceEpoch}';
    }
    return id;
  }

  /// Sanitized patientId when non-empty (so two devices editing "the same
  /// patient" converge on one Firestore doc instead of duplicating);
  /// falls back to syncId for the locally-allowed blank-patientId rows
  /// (e.g. spreadsheet imports without an ID column).
  static String patientDocId(Patient p) =>
      sanitizeDocId(p.patientId.isNotEmpty ? p.patientId : p.syncId);

  /// Print records always use syncId — never epc_code/tid_code (those encode
  /// RFID tag content, not sync identity) and never the local SQLite id.
  static String printRecordDocId(PrintRecord r) => sanitizeDocId(r.syncId);

  /// The `updateTime` Firestore returns on every document read — used as the
  /// optimistic-concurrency precondition on push (see FirebaseService).
  static String? updateTimeOf(Map<String, dynamic> doc) => doc['updateTime'] as String?;

  // ─── Patient ─────────────────────────────────────────────────────────────

  static const patientFieldNames = [
    'patientId', 'name', 'gender', 'dateOfBirth', 'bloodType', 'department',
    'doctor', 'allergy', 'admissionTime', 'createdAt', 'updatedAt', 'syncId',
  ];

  static Map<String, dynamic> patientFields(Patient p) => {
        'patientId': _val(p.patientId),
        'name': _val(p.name),
        'gender': _val(p.gender),
        'dateOfBirth': _val(p.dateOfBirth),
        'bloodType': _val(p.bloodType),
        'department': _val(p.department),
        'doctor': _val(p.doctor),
        'allergy': _val(p.allergy),
        'admissionTime': _val(p.admissionTime),
        'createdAt': _val(p.createdAt),
        'updatedAt': _val(p.updatedAt),
        'syncId': _val(p.syncId),
      };

  /// Parses a Firestore document's `fields` map back into a Patient.
  /// `dirty` is always false — data freshly pulled from Firestore is, by
  /// definition, already in sync with the cloud.
  static Patient patientFromFields(Map<String, dynamic> fields) => Patient(
        patientId: _str(fields, 'patientId'),
        name: _str(fields, 'name'),
        gender: _str(fields, 'gender'),
        dateOfBirth: _str(fields, 'dateOfBirth'),
        bloodType: _str(fields, 'bloodType'),
        department: _str(fields, 'department'),
        doctor: _str(fields, 'doctor'),
        allergy: _str(fields, 'allergy'),
        admissionTime: _str(fields, 'admissionTime'),
        createdAt: _dateTime(fields, 'createdAt'),
        updatedAt: _dateTime(fields, 'updatedAt'),
        syncId: _str(fields, 'syncId'),
        dirty: false,
      );

  // ─── PrintRecord ─────────────────────────────────────────────────────────

  static const printRecordFieldNames = [
    'patientId', 'name', 'gender', 'dateOfBirth', 'bloodType', 'allergy',
    'department', 'doctor', 'admissionTime', 'epcCode', 'tidCode', 'printTime', 'syncId',
  ];

  static Map<String, dynamic> printRecordFields(PrintRecord r) => {
        'patientId': _val(r.patientId),
        'name': _val(r.name),
        'gender': _val(r.gender),
        'dateOfBirth': _val(r.dateOfBirth),
        'bloodType': _val(r.bloodType),
        'allergy': _val(r.allergy),
        'department': _val(r.department),
        'doctor': _val(r.doctor),
        'admissionTime': _val(r.admissionTime),
        'epcCode': _val(r.epcCode),
        'tidCode': _val(r.tidCode),
        'printTime': _val(r.printTime),
        'syncId': _val(r.syncId),
      };

  static PrintRecord printRecordFromFields(Map<String, dynamic> fields) => PrintRecord(
        name: _str(fields, 'name'),
        patientId: _str(fields, 'patientId'),
        gender: _str(fields, 'gender'),
        dateOfBirth: _str(fields, 'dateOfBirth'),
        bloodType: _str(fields, 'bloodType'),
        allergy: _str(fields, 'allergy'),
        department: _str(fields, 'department'),
        doctor: _str(fields, 'doctor'),
        admissionTime: _str(fields, 'admissionTime'),
        epcCode: _str(fields, 'epcCode'),
        tidCode: _str(fields, 'tidCode'),
        printTime: _dateTime(fields, 'printTime'),
        syncId: _str(fields, 'syncId'),
      );
}
