import 'package:flutter_test/flutter_test.dart';

import 'package:baobi_wristband/models/patient.dart';
import 'package:baobi_wristband/models/print_record.dart';
import 'package:baobi_wristband/services/firestore_codec.dart';

/// Pure-function tests for the Firestore REST typed-value (de)serialization —
/// no network/emulator needed. Specifically covers the gotchas that are easy
/// to get wrong with Firestore's REST wire format vs a normal JSON API.
void main() {
  group('Patient <-> Firestore fields', () {
    test('round-trips every field correctly', () {
      final p = Patient(
        name: 'Chen Wei', gender: 'Male', patientId: 'P100',
        allergy: 'Penicillin', bloodType: 'O+', department: 'Cardiology',
        doctor: 'Dr. Zhang', dateOfBirth: '1985.03.12', admissionTime: '2026.07.16 09:00',
      );
      final fields = FirestoreCodec.patientFields(p);
      final back = FirestoreCodec.patientFromFields(fields);

      expect(back.name, p.name);
      expect(back.patientId, p.patientId);
      expect(back.gender, p.gender);
      expect(back.allergy, p.allergy);
      expect(back.bloodType, p.bloodType);
      expect(back.department, p.department);
      expect(back.doctor, p.doctor);
      expect(back.dateOfBirth, p.dateOfBirth);
      expect(back.admissionTime, p.admissionTime);
      expect(back.syncId, p.syncId);
    });

    test('pulled data is never dirty, regardless of source dirty flag', () {
      final p = Patient(name: 'X', gender: 'Male', patientId: 'P1', dirty: true);
      final back = FirestoreCodec.patientFromFields(FirestoreCodec.patientFields(p));
      expect(back.dirty, isFalse,
          reason: 'data freshly pulled from Firestore is by definition already synced');
    });

    test('timestampValue is UTC RFC3339, not a bare local ISO string', () {
      final local = DateTime(2026, 7, 16, 14, 30, 0); // no timezone info
      final p = Patient(name: 'X', gender: 'Male', patientId: 'P1', createdAt: local, updatedAt: local);
      final fields = FirestoreCodec.patientFields(p);

      final ts = fields['createdAt']['timestampValue'] as String;
      expect(ts.endsWith('Z'), isTrue,
          reason: 'Firestore REST requires an explicit UTC offset or it 400s');
      expect(DateTime.parse(ts).toUtc(), local.toUtc());
    });

    test('empty string fields round-trip as empty string, not null', () {
      final p = Patient(name: 'X', gender: 'Male', patientId: 'P1'); // allergy etc. default to ''
      final back = FirestoreCodec.patientFromFields(FirestoreCodec.patientFields(p));
      expect(back.allergy, '');
      expect(back.department, '');
    });

    test('doc ID uses sanitized patientId when non-empty', () {
      expect(FirestoreCodec.patientDocId(
        Patient(name: 'X', gender: 'Male', patientId: 'P/100'),
      ), 'P_100');
    });

    test('doc ID falls back to syncId when patientId is blank', () {
      final p = Patient(name: 'X', gender: 'Male', patientId: '');
      expect(FirestoreCodec.patientDocId(p), p.syncId);
    });
  });

  group('PrintRecord <-> Firestore fields', () {
    test('round-trips every field correctly', () {
      final r = PrintRecord(
        name: 'John Doe', patientId: 'P200', epcCode: 'EPC-1', tidCode: 'TID-1',
        gender: 'Male', bloodType: 'A+',
      );
      final back = FirestoreCodec.printRecordFromFields(FirestoreCodec.printRecordFields(r));
      expect(back.name, r.name);
      expect(back.patientId, r.patientId);
      expect(back.epcCode, r.epcCode);
      expect(back.tidCode, r.tidCode);
      expect(back.syncId, r.syncId);
    });

    test('doc ID always uses syncId, never epc/tid code', () {
      final r = PrintRecord(name: 'X', patientId: 'P1', epcCode: 'EPC-1', tidCode: 'TID-1');
      expect(FirestoreCodec.printRecordDocId(r), r.syncId);
      expect(FirestoreCodec.printRecordDocId(r), isNot(r.epcCode));
      expect(FirestoreCodec.printRecordDocId(r), isNot(r.tidCode));
    });
  });

  group('updateTimeOf', () {
    test('reads the top-level updateTime from a Firestore document envelope', () {
      final doc = {
        'name': 'projects/x/databases/(default)/documents/hospitals/u1/patients/P1',
        'fields': <String, dynamic>{},
        'createTime': '2026-07-16T09:00:00.000Z',
        'updateTime': '2026-07-16T09:05:00.000Z',
      };
      expect(FirestoreCodec.updateTimeOf(doc), '2026-07-16T09:05:00.000Z');
    });

    test('returns null when absent', () {
      expect(FirestoreCodec.updateTimeOf({'fields': <String, dynamic>{}}), isNull);
    });
  });
}
