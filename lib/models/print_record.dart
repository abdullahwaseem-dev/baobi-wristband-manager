class PrintRecord {
  final int? id;
  final String name;
  final String patientId;
  final String gender;
  final String dateOfBirth;
  final String bloodType;
  final String allergy;
  final String department;
  final String doctor;
  final String admissionTime;
  final String epcCode;
  final String tidCode;
  final DateTime printTime;

  /// Stable cross-device identity for Firebase sync (Firestore doc ID) and a
  /// free idempotency key on push retries. Print records are append-only —
  /// never epc_code/tid_code, which encode RFID tag content, not sync
  /// bookkeeping, and never the local SQLite [id].
  final String syncId;

  PrintRecord({
    this.id,
    required this.name,
    required this.patientId,
    this.gender = '',
    this.dateOfBirth = '',
    this.bloodType = '',
    this.allergy = '',
    this.department = '',
    this.doctor = '',
    this.admissionTime = '',
    required this.epcCode,
    required this.tidCode,
    DateTime? printTime,
    String? syncId,
  })  : printTime = printTime ?? DateTime.now(),
        syncId = (syncId == null || syncId.isEmpty) ? _newSyncId() : syncId;

  static int _syncIdCounter = 0;
  static String _newSyncId() {
    _syncIdCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_syncIdCounter';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'patient_id': patientId,
        'gender': gender,
        'date_of_birth': dateOfBirth,
        'blood_type': bloodType,
        'allergy': allergy,
        'department': department,
        'doctor': doctor,
        'admission_time': admissionTime,
        'epc_code': epcCode,
        'tid_code': tidCode,
        'print_time': printTime.toIso8601String(),
        'sync_id': syncId,
      };

  factory PrintRecord.fromMap(Map<String, dynamic> m) => PrintRecord(
        id: m['id'] as int?,
        name: m['name'] ?? '',
        patientId: m['patient_id'] ?? '',
        gender: m['gender'] ?? '',
        dateOfBirth: m['date_of_birth'] ?? '',
        bloodType: m['blood_type'] ?? '',
        allergy: m['allergy'] ?? '',
        department: m['department'] ?? '',
        doctor: m['doctor'] ?? '',
        admissionTime: m['admission_time'] ?? '',
        epcCode: m['epc_code'] ?? '',
        tidCode: m['tid_code'] ?? '',
        printTime: DateTime.tryParse(m['print_time'] ?? '') ?? DateTime.now(),
        syncId: m['sync_id'] as String?,
      );
}
