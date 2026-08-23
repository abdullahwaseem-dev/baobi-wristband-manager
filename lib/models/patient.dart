class Patient {
  final int? id;
  final String name;
  final String gender;
  final String patientId;
  final String allergy;
  final String bloodType;
  final String department;
  final String doctor;
  final String dateOfBirth;
  final String admissionTime;
  final DateTime createdAt;

  /// Stable cross-device identity for Firebase sync — never the local SQLite
  /// [id], which gets silently reassigned on every ConflictAlgorithm.replace
  /// upsert (HIS sync, Excel import) and is therefore not safe to use as a
  /// Firestore document ID or to correlate the "same" patient across devices.
  final String syncId;

  /// Last local modification time.
  final DateTime updatedAt;

  /// True when this row has local changes not yet pushed to Firestore.
  /// Defaults to true because most call sites (Add/Edit dialogs, HIS sync,
  /// Excel import) construct genuinely new local data; the Firestore-pull
  /// path is the only place that explicitly passes `dirty: false`.
  final bool dirty;

  /// The Firestore document `updateTime` this device last saw for this
  /// patient (raw RFC3339 string, opaque — never parsed, only echoed back).
  /// Null means "never pulled/pushed" — push then proceeds without an
  /// optimistic-concurrency precondition, since there's nothing to conflict
  /// with yet. Used to detect "someone else wrote this since I last saw it"
  /// on push (see FirebaseService).
  final String? remoteUpdateTime;

  Patient({
    this.id,
    required this.name,
    required this.gender,
    required this.patientId,
    this.allergy = '',
    this.bloodType = '',
    this.department = '',
    this.doctor = '',
    this.dateOfBirth = '',
    this.admissionTime = '',
    DateTime? createdAt,
    String? syncId,
    DateTime? updatedAt,
    this.dirty = true,
    this.remoteUpdateTime,
  })  : createdAt = createdAt ?? DateTime.now(),
        syncId = (syncId == null || syncId.isEmpty) ? _newSyncId() : syncId,
        updatedAt = updatedAt ?? DateTime.now();

  static int _syncIdCounter = 0;
  static String _newSyncId() {
    // Lightweight unique ID: timestamp + process-local counter. Avoids
    // pulling in the `uuid` package's Random-based v4 generator for every
    // Patient construction (this runs on every Add/Edit/HIS-sync row);
    // uniqueness only needs to hold within one device's local database plus
    // whatever this device pushes to Firestore, which this satisfies.
    _syncIdCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}-$_syncIdCounter';
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'gender': gender,
        'patient_id': patientId,
        'allergy': allergy,
        'blood_type': bloodType,
        'department': department,
        'doctor': doctor,
        'date_of_birth': dateOfBirth,
        'admission_time': admissionTime,
        'created_at': createdAt.toIso8601String(),
        'sync_id': syncId,
        'updated_at': updatedAt.toIso8601String(),
        'dirty': dirty ? 1 : 0,
        'remote_update_time': remoteUpdateTime,
      };

  factory Patient.fromMap(Map<String, dynamic> m) => Patient(
        id: m['id'] as int?,
        name: m['name'] ?? '',
        gender: m['gender'] ?? '',
        patientId: m['patient_id'] ?? '',
        allergy: m['allergy'] ?? '',
        bloodType: m['blood_type'] ?? '',
        department: m['department'] ?? '',
        doctor: m['doctor'] ?? '',
        dateOfBirth: m['date_of_birth'] ?? '',
        admissionTime: m['admission_time'] ?? '',
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        syncId: m['sync_id'] as String?,
        updatedAt: DateTime.tryParse(m['updated_at'] ?? ''),
        dirty: (m['dirty'] as int?) == 1,
        remoteUpdateTime: m['remote_update_time'] as String?,
      );

  Patient copyWith({
    int? id,
    String? name,
    String? gender,
    String? patientId,
    String? allergy,
    String? bloodType,
    String? department,
    String? doctor,
    String? dateOfBirth,
    String? admissionTime,
    String? syncId,
    DateTime? updatedAt,
    bool? dirty,
    String? remoteUpdateTime,
  }) =>
      Patient(
        id: id ?? this.id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        patientId: patientId ?? this.patientId,
        allergy: allergy ?? this.allergy,
        bloodType: bloodType ?? this.bloodType,
        department: department ?? this.department,
        doctor: doctor ?? this.doctor,
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        admissionTime: admissionTime ?? this.admissionTime,
        createdAt: createdAt,
        syncId: syncId ?? this.syncId,
        updatedAt: updatedAt ?? this.updatedAt,
        dirty: dirty ?? this.dirty,
        remoteUpdateTime: remoteUpdateTime ?? this.remoteUpdateTime,
      );
}
