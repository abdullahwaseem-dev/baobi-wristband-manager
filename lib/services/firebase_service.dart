import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/patient.dart';
import '../models/print_record.dart';
import 'firebase_auth_service.dart';
import 'firebase_env.dart';
import 'firestore_codec.dart';
import 'settings_service.dart';

/// Firestore REST client, scoped to the signed-in hospital account's own UID
/// (see firestore.rules) — `/hospitals/{hospitalUid}/...`. One shared login
/// per hospital; every station signed in as that account sees the same data.
///
/// Note on `:batchWrite`: the originally-planned design used Firestore's
/// `:batchWrite` endpoint for efficient bulk pushes. Empirically verified
/// against a real emulator, `:batchWrite` requires admin/service-account
/// authentication and rejects a normal signed-in user's ID token outright —
/// it's meant for trusted backends, not client apps, and bypasses security
/// rules entirely (which would defeat the point here). Individual PATCH
/// requests per document — sent with bounded concurrency rather than fully
/// serial or fully parallel — turned out to be the correct approach anyway,
/// since it gives natural per-document partial-success semantics without
/// needing to parse a batch status array.
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  final FirebaseAuthService _auth = FirebaseAuthService.instance;

  bool get isReady => FirebaseEnv.isConfigured && _auth.isSignedIn;

  String get _documentsRoot =>
      '${FirebaseEnv.firestoreBaseUrl}/v1/projects/${FirebaseEnv.projectId}/databases/(default)/documents';

  /// Resource name with no `https://.../v1/` prefix — the form Firestore's
  /// `:commit` body wants in `write.update.name`, as opposed to a request URL.
  String get _hospitalResourceRoot =>
      'projects/${FirebaseEnv.projectId}/databases/(default)/documents/hospitals/${_auth.hospitalUid}';

  /// Full REST URL for this hospital's subtree.
  String get _basePath => '$_documentsRoot/hospitals/${_auth.hospitalUid}';

  Future<Map<String, String>?> _authHeaders() async {
    final token = await _auth.validIdToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
  }

  // ─── Patients: pull ──────────────────────────────────────────────────────────

  /// Single-document GET for one patient ID — the cheap counterpart to
  /// [pullPatients], used by the Print screen's "Sync HIS" button as a
  /// fallback when the hospital's own HIS doesn't have the patient (e.g. a
  /// walk-in already added at another station and pushed to the cloud, but
  /// not yet present in the HIS). Never triggers a full-collection read.
  Future<({Patient? patient, String? error})> pullOnePatient(String patientId) async {
    if (!isReady) return (patient: null, error: 'Not signed in to Firebase.');
    if (patientId.trim().isEmpty) return (patient: null, error: null);
    final headers = await _authHeaders();
    if (headers == null) return (patient: null, error: 'Firebase session expired — sign in again.');

    try {
      final docId = FirestoreCodec.sanitizeDocId(patientId.trim());
      final uri = Uri.parse('$_basePath/patients/$docId');
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 404) return (patient: null, error: null);
      if (resp.statusCode != 200) {
        return (patient: null, error: 'Firestore returned HTTP ${resp.statusCode}.');
      }
      final doc = json.decode(resp.body) as Map<String, dynamic>;
      final fields = ((doc['fields'] as Map?) ?? const {}).cast<String, dynamic>();
      final patient = FirestoreCodec.patientFromFields(fields).copyWith(
        remoteUpdateTime: FirestoreCodec.updateTimeOf(doc),
      );
      return (patient: patient, error: null);
    } on Exception catch (e) {
      return (patient: null, error: _friendlyError(e));
    }
  }

  Future<({List<Patient> patients, String? error})> pullPatients() async {
    if (!isReady) return (patients: <Patient>[], error: 'Not signed in to Firebase.');
    final headers = await _authHeaders();
    if (headers == null) return (patients: <Patient>[], error: 'Firebase session expired — sign in again.');

    final all = <Patient>[];
    try {
      String? pageToken;
      do {
        final uri = Uri.parse('$_basePath/patients').replace(queryParameters: {
          'pageSize': '300',
          'pageToken': ?pageToken,
        });
        final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
        if (resp.statusCode != 200) {
          return (patients: <Patient>[], error: 'Firestore returned HTTP ${resp.statusCode} while pulling patients.');
        }
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final docs = (body['documents'] as List?) ?? const [];
        for (final raw in docs) {
          final doc = (raw as Map).cast<String, dynamic>();
          final fields = ((doc['fields'] as Map?) ?? const {}).cast<String, dynamic>();
          all.add(FirestoreCodec.patientFromFields(fields).copyWith(
            remoteUpdateTime: FirestoreCodec.updateTimeOf(doc),
          ));
        }
        pageToken = body['nextPageToken'] as String?;
      } while (pageToken != null);
    } on Exception catch (e) {
      return (patients: <Patient>[], error: _friendlyError(e));
    }
    return (patients: all, error: null);
  }

  // ─── Patients: push ──────────────────────────────────────────────────────────
  // Bounded-concurrency fan-out of single-write :commit calls (see class doc
  // for why not :batchWrite). Each write carries an optimistic-concurrency
  // precondition (currentDocument.updateTime) whenever this device has
  // previously seen a remote version of the doc — a 400/FAILED_PRECONDITION
  // means someone else wrote it first, surfaced to the caller as a conflict
  // rather than silently overwritten.
  //
  // Note: Firestore's simple PATCH endpoint nominally accepts
  // `currentDocument.updateTime` as a query parameter per the REST API
  // reference, but empirically (verified against a real emulator) it is NOT
  // honored there — every precondition-bearing PATCH fails with "required
  // base version (0)" regardless of the timestamp supplied, i.e. the query
  // param is silently ignored. The :commit endpoint's structured JSON body
  // (`writes[].currentDocument.updateTime`) DOES work correctly — verified
  // for both the matching-precondition-succeeds and stale-precondition-fails
  // cases — so pushes go through :commit with a single write per call
  // instead, preserving the same one-request-per-document / bounded-
  // concurrency shape.

  Future<({List<Patient> succeeded, List<Patient> conflicted, String? error})> pushPatients(
    List<Patient> dirty,
  ) async {
    if (!isReady) {
      return (succeeded: <Patient>[], conflicted: <Patient>[], error: 'Not signed in to Firebase.');
    }
    if (dirty.isEmpty) return (succeeded: <Patient>[], conflicted: <Patient>[], error: null);
    final headers = await _authHeaders();
    if (headers == null) {
      return (succeeded: <Patient>[], conflicted: <Patient>[], error: 'Firebase session expired — sign in again.');
    }

    final succeeded = <Patient>[];
    final conflicted = <Patient>[];
    var index = 0;
    const concurrency = 8;

    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= dirty.length) return;
        final p = dirty[i];
        final result = await _pushOnePatient(p, headers);
        if (result.succeeded != null) {
          succeeded.add(result.succeeded!);
        } else if (result.conflict) {
          conflicted.add(p);
        }
        // else: a transient per-doc failure (network blip) — the row stays
        // dirty locally and is retried in full on the next sync tick.
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    return (succeeded: succeeded, conflicted: conflicted, error: null);
  }

  Future<({Patient? succeeded, bool conflict})> _pushOnePatient(
    Patient p,
    Map<String, String> headers,
  ) async {
    try {
      final docId = FirestoreCodec.patientDocId(p);
      final write = {
        'update': {
          'name': '$_hospitalResourceRoot/patients/$docId',
          'fields': FirestoreCodec.patientFields(p),
        },
        'updateMask': {'fieldPaths': FirestoreCodec.patientFieldNames},
        if (p.remoteUpdateTime != null) 'currentDocument': {'updateTime': p.remoteUpdateTime},
      };
      final uri = Uri.parse('$_documentsRoot:commit');
      final resp = await http
          .post(uri, headers: headers, body: json.encode({'writes': [write]}))
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body) as Map<String, dynamic>;
        final writeResults = body['writeResults'] as List?;
        final newUpdateTime = (writeResults != null && writeResults.isNotEmpty)
            ? (writeResults.first as Map<String, dynamic>)['updateTime'] as String?
            : null;
        return (
          succeeded: p.copyWith(dirty: false, remoteUpdateTime: newUpdateTime),
          conflict: false,
        );
      }
      if (resp.statusCode == 400 && resp.body.contains('FAILED_PRECONDITION')) {
        return (succeeded: null, conflict: true);
      }
      return (succeeded: null, conflict: false);
    } catch (_) {
      return (succeeded: null, conflict: false);
    }
  }

  // ─── Print records: pull (incremental) ────────────────────────────────────────

  Future<({List<PrintRecord> records, String? error})> pullPrintRecords() async {
    if (!isReady) return (records: <PrintRecord>[], error: 'Not signed in to Firebase.');
    final headers = await _authHeaders();
    if (headers == null) return (records: <PrintRecord>[], error: 'Firebase session expired — sign in again.');

    final all = <PrintRecord>[];
    try {
      final cursor = SettingsService.instance.lastSyncedPrintTime;
      final structuredQuery = <String, dynamic>{
        'from': [
          {'collectionId': 'printRecords'}
        ],
        'orderBy': [
          {
            'field': {'fieldPath': 'printTime'},
            'direction': 'ASCENDING',
          }
        ],
        if (cursor.isNotEmpty)
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'printTime'},
              'op': 'GREATER_THAN',
              'value': {'timestampValue': cursor},
            }
          },
      };
      final uri = Uri.parse('$_basePath:runQuery');
      final resp = await http
          .post(uri, headers: headers, body: json.encode({'structuredQuery': structuredQuery}))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200) {
        return (records: <PrintRecord>[], error: 'Firestore returned HTTP ${resp.statusCode} while pulling print records.');
      }

      final results = json.decode(resp.body) as List;
      String? latestPrintTime;
      for (final raw in results) {
        final entry = (raw as Map).cast<String, dynamic>();
        final doc = entry['document'] as Map<String, dynamic>?;
        if (doc == null) continue; // heartbeat/progress entry, no document
        final fields = ((doc['fields'] as Map?) ?? const {}).cast<String, dynamic>();
        all.add(FirestoreCodec.printRecordFromFields(fields));
        final ts = fields['printTime'] as Map<String, dynamic>?;
        final tsValue = ts?['timestampValue'] as String?;
        if (tsValue != null) latestPrintTime = tsValue; // ASCENDING order -> last one is newest
      }
      if (latestPrintTime != null) {
        await SettingsService.instance.setLastSyncedPrintTime(latestPrintTime);
      }
    } on Exception catch (e) {
      return (records: <PrintRecord>[], error: _friendlyError(e));
    }
    return (records: all, error: null);
  }

  // ─── Print records: push ────────────────────────────────────────────────────
  // Append-only, idempotent by syncId — no conflict logic needed, unlike
  // patients. Same bounded-concurrency PATCH pattern, no precondition.

  Future<({List<PrintRecord> succeeded, String? error})> pushPrintRecords(List<PrintRecord> records) async {
    if (!isReady) return (succeeded: <PrintRecord>[], error: 'Not signed in to Firebase.');
    if (records.isEmpty) return (succeeded: <PrintRecord>[], error: null);
    final headers = await _authHeaders();
    if (headers == null) {
      return (succeeded: <PrintRecord>[], error: 'Firebase session expired — sign in again.');
    }

    final succeeded = <PrintRecord>[];
    var index = 0;
    const concurrency = 8;

    Future<void> worker() async {
      while (true) {
        final i = index++;
        if (i >= records.length) return;
        final r = records[i];
        try {
          final docId = FirestoreCodec.printRecordDocId(r);
          final uri = Uri.parse('$_basePath/printRecords/$docId').replace(queryParameters: {
            'updateMask.fieldPaths': FirestoreCodec.printRecordFieldNames,
          });
          final resp = await http
              .patch(uri, headers: headers, body: json.encode({'fields': FirestoreCodec.printRecordFields(r)}))
              .timeout(const Duration(seconds: 15));
          if (resp.statusCode == 200) succeeded.add(r);
        } catch (_) {
          // transient failure — this record simply isn't marked pushed and
          // will be retried on the next sync tick.
        }
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    return (succeeded: succeeded, error: null);
  }

  // ─── Maintenance: delete all cloud data ─────────────────────────────────────
  // Deliberately separate from, and far more destructive than, the local
  // "Reset Local Cache" action — this removes data shared by every station
  // syncing with this hospital's account. Firestore's REST API has no single
  // "delete collection" call: list every doc (paginated), then issue
  // bounded-concurrency DELETE requests per doc.

  Future<({int deleted, String? error})> deleteAllHospitalData() async {
    if (!isReady) return (deleted: 0, error: 'Not signed in to Firebase.');
    final headers = await _authHeaders();
    if (headers == null) return (deleted: 0, error: 'Firebase session expired — sign in again.');

    try {
      var deleted = 0;
      for (final collection in ['patients', 'printRecords']) {
        final docNames = <String>[];
        String? pageToken;
        do {
          final uri = Uri.parse('$_basePath/$collection').replace(queryParameters: {
            'pageSize': '300',
            'pageToken': ?pageToken,
            'mask.fieldPaths': 'syncId', // minimize payload — only need doc names
          });
          final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));
          if (resp.statusCode != 200) {
            return (deleted: deleted, error: 'Firestore returned HTTP ${resp.statusCode} while listing $collection.');
          }
          final body = json.decode(resp.body) as Map<String, dynamic>;
          final docs = (body['documents'] as List?) ?? const [];
          for (final raw in docs) {
            docNames.add(((raw as Map)['name'] as String));
          }
          pageToken = body['nextPageToken'] as String?;
        } while (pageToken != null);

        var index = 0;
        const concurrency = 8;
        Future<void> worker() async {
          while (true) {
            final i = index++;
            if (i >= docNames.length) return;
            try {
              final uri = Uri.parse('${FirebaseEnv.firestoreBaseUrl}/v1/${docNames[i]}');
              final resp = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
              if (resp.statusCode == 200) deleted++;
            } catch (_) {
              // leave it — a re-run of this action will pick up any stragglers
            }
          }
        }

        await Future.wait(List.generate(concurrency, (_) => worker()));
      }
      return (deleted: deleted, error: null);
    } on Exception catch (e) {
      return (deleted: 0, error: _friendlyError(e));
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup')) {
      return 'Cannot reach Firebase — check your internet connection.';
    }
    if (msg.contains('TimeoutException')) {
      return 'Firebase request timed out.';
    }
    return 'Firebase sync error: $msg';
  }
}
