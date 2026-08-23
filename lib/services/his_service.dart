import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import '../models/patient.dart';
import '../models/his_config.dart';
import 'settings_service.dart';

/// Talks to a hospital HIS / patient database over a REST API.
///
/// Designed to be forgiving of the many small differences between real
/// hospital systems: trailing/leading slashes, nested JSON, varied auth
/// schemes, "not found" responses that still return HTTP 200, and internal
/// HTTPS servers using a self-signed or internally-issued certificate.
class HisService {
  HisService._();
  static final HisService instance = HisService._();

  HisConfig get _cfg => SettingsService.instance.hisConfig;

  // ─── HTTP client ─────────────────────────────────────────────────────────────
  // Hospital intranets very commonly run HTTPS with an internal/self-signed
  // certificate that a normal HttpClient will reject outright. When the user
  // has explicitly opted in via `allowSelfSignedCert`, we build a client that
  // accepts any certificate — scoped to this one request, never global.

  http.Client _clientFor(HisConfig cfg) {
    if (cfg.allowSelfSignedCert) {
      final io = HttpClient()..badCertificateCallback = (cert, host, port) => true;
      return IOClient(io);
    }
    return http.Client();
  }

  Future<http.Response> _httpGet(HisConfig cfg, Uri uri, Duration timeout) async {
    final client = _clientFor(cfg);
    try {
      return await client.get(uri, headers: _headers(cfg)).timeout(timeout);
    } finally {
      client.close();
    }
  }

  // ─── Auth headers ──────────────────────────────────────────────────────────
  // Note: we set `Accept` (not `Content-Type`) on GET requests — a bodyless GET
  // with a Content-Type header is rejected by some strict servers/WAFs.

  Map<String, String> _headers(HisConfig cfg) {
    final h = <String, String>{'Accept': 'application/json'};
    switch (cfg.authType) {
      case 'basic':
        if (cfg.username.isNotEmpty || cfg.password.isNotEmpty) {
          final encoded = base64Encode(utf8.encode('${cfg.username}:${cfg.password}'));
          h['Authorization'] = 'Basic $encoded';
        }
      case 'bearer':
        if (cfg.bearerToken.isNotEmpty) {
          h['Authorization'] = 'Bearer ${cfg.bearerToken}';
        }
      case 'apikey':
        final header = cfg.apiKeyHeader.trim().isEmpty ? 'X-API-Key' : cfg.apiKeyHeader.trim();
        if (cfg.apiKey.isNotEmpty) h[header] = cfg.apiKey;
    }
    return h;
  }

  // ─── URL building ──────────────────────────────────────────────────────────
  // Normalises the join between base URL and endpoint so that common
  // data-entry mistakes ("http://host/api/" + "patient/{id}") still produce a
  // valid URL instead of a silent 404.

  Uri _buildUri(HisConfig cfg, String endpoint, {Map<String, String>? query}) {
    var base = cfg.baseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    var path = endpoint.trim();
    if (path.isNotEmpty && !path.startsWith('/') && !path.startsWith('?')) {
      path = '/$path';
    }
    final uri = Uri.parse('$base$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  // ─── Field extraction ────────────────────────────────────────────────────────
  // Supports flat keys ("name") and dot-notation for nested JSON
  // ("demographics.bloodGroup", "patient.name.full"), which real HIS payloads
  // frequently use.

  String _get(Map data, String key) {
    if (key.isEmpty) return '';
    dynamic cur = data;
    for (final part in key.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return '';
      }
    }
    if (cur == null) return '';
    return cur.toString().trim();
  }

  /// Returns null when the object is empty/garbage (no id and no name) so the
  /// caller can treat it as "not found" rather than fabricating a blank patient.
  Patient? _parsePatient(Map d, HisConfig cfg, String fallbackId) {
    final mappedId = _get(d, cfg.fPatientId);
    final name     = _get(d, cfg.fName);
    if (mappedId.isEmpty && name.isEmpty) return null;
    final blood = _get(d, cfg.fBloodType);
    return Patient(
      patientId:     mappedId.isEmpty ? fallbackId : mappedId,
      name:          name,
      gender:        _normaliseGender(_get(d, cfg.fGender)),
      dateOfBirth:   _get(d, cfg.fDateOfBirth),
      bloodType:     blood.isEmpty ? 'A+' : blood,
      department:    _get(d, cfg.fDepartment),
      doctor:        _get(d, cfg.fDoctor),
      allergy:       _get(d, cfg.fAllergy),
      admissionTime: _get(d, cfg.fAdmissionTime),
      // Not a local UI edit — a repeated HIS sync must be free to refresh
      // its own previously-synced rows. `dirty` here is reserved for
      // protecting genuine local edits (Add/Edit dialogs) from being
      // clobbered by a subsequent bulk sync, not for tracking "needs a
      // Firestore push" (that's handled separately once Firebase sync lands).
      dirty: false,
    );
  }

  String _normaliseGender(String raw) {
    final g = raw.toLowerCase().trim();
    if (g == 'm' || g == 'male' || g == '男' || g == '1') return 'Male';
    if (g == 'f' || g == 'female' || g == '女' || g == '2') return 'Female';
    return raw.isEmpty ? 'Male' : raw;
  }

  /// Unwraps the payload root, e.g. `{"data":[...]}` → `[...]` when
  /// [arrayKey] is "data". Dot-notation is supported here too.
  dynamic _extractRoot(dynamic body, String arrayKey) {
    if (arrayKey.isEmpty || body is! Map) return body;
    dynamic cur = body;
    for (final part in arrayKey.split('.')) {
      if (cur is Map && cur.containsKey(part)) {
        cur = cur[part];
      } else {
        return body; // key not present — fall back to the raw body
      }
    }
    return cur;
  }

  /// The configured Department, as a standalone request parameter sent on
  /// every HIS call — distinct from [HisConfig.fDepartment], which only maps
  /// the JSON key holding a department name in the HIS's response. Null when
  /// unset, so callers merging it into their own query map don't need to
  /// special-case emptiness.
  Map<String, String>? _departmentQuery(HisConfig cfg) =>
      cfg.department.trim().isEmpty ? null : {'department': cfg.department.trim()};

  // ─── Fetch single patient by ID ───────────────────────────────────────────────
  // Returns a diagnostic reason on failure (surfaced in the app UI) instead of
  // the old "not found or network error" catch-all — that ambiguity made real
  // failures (wrong URL, wrong field mapping, auth failure, TLS issue) all but
  // impossible to tell apart on-site.

  Future<({Patient? patient, String? error})> fetchPatientById(String patientId) async {
    final cfg = _cfg;
    if (!cfg.isConfigured) {
      return (patient: null, error: 'HIS is not configured yet — set it up in System Settings first.');
    }
    if (patientId.trim().isEmpty) {
      return (patient: null, error: 'Enter a Patient ID first.');
    }
    final path = cfg.searchEndpoint.replaceAll('{id}', Uri.encodeComponent(patientId.trim()));
    final uri  = _buildUri(cfg, path, query: _departmentQuery(cfg));
    try {
      final response = await _httpGet(cfg, uri, const Duration(seconds: 10));
      if (response.statusCode == 401) {
        return (patient: null, error: 'Authentication failed (401) at $uri — check the Auth tab.');
      }
      if (response.statusCode == 403) {
        return (patient: null, error: 'Access denied (403) at $uri — check credentials/permissions.');
      }
      if (response.statusCode == 404) {
        return (patient: null, error: 'Endpoint not found (404) at $uri — check the Search Endpoint on the Endpoints tab.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (patient: null, error: 'Server returned HTTP ${response.statusCode} at $uri.');
      }
      if (response.body.trim().isEmpty) {
        return (patient: null, error: 'Server returned an empty response at $uri.');
      }

      final decoded = json.decode(response.body);
      final data = _extractRoot(decoded, cfg.searchResponseKey);

      Map? record;
      if (data is List) {
        record = data.whereType<Map>().cast<Map?>().firstWhere(
              (_) => true,
              orElse: () => null,
            );
      } else if (data is Map) {
        record = data;
      }
      if (record == null) {
        return (patient: null, error: 'No patient found with ID "$patientId".');
      }

      final patient = _parsePatient(record, cfg, patientId.trim());
      // A hit must have a usable name — otherwise it's an empty/not-found
      // response and we must NOT silently autofill a blank patient.
      if (patient == null || patient.name.isEmpty) {
        return (
          patient: null,
          error: 'No patient found with ID "$patientId" — or the "Name" mapping on the '
              'Field Map tab does not match this server\'s JSON field.',
        );
      }
      return (patient: patient, error: null);
    } on FormatException {
      return (patient: null, error: 'Server response at $uri was not valid JSON — check the endpoint URL.');
    } on Exception catch (e) {
      return (patient: null, error: _friendlyError(e, uri, cfg));
    }
  }

  // ─── Batch sync (fetch all / by ward) ────────────────────────────────────────

  Future<({List<Patient> patients, String? error})> batchSync(String ward) async {
    final cfg = _cfg;
    if (!cfg.isConfigured) {
      return (patients: <Patient>[], error: 'HIS is not configured yet — set it up in System Settings first.');
    }
    final query = <String, String>{
      ...?_departmentQuery(cfg),
      if (ward.trim().isNotEmpty) 'ward': ward.trim(),
    };
    final uri = _buildUri(cfg, cfg.listEndpoint, query: query.isEmpty ? null : query);
    try {
      final response = await _httpGet(cfg, uri, const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (patients: <Patient>[], error: 'Server returned HTTP ${response.statusCode} at $uri.');
      }
      if (response.body.trim().isEmpty) {
        return (patients: <Patient>[], error: 'Server returned an empty response at $uri.');
      }

      final decoded = json.decode(response.body);
      final list = _extractRoot(decoded, cfg.listArrayKey);
      if (list is! List) {
        return (
          patients: <Patient>[],
          error: 'Expected a list of patients at $uri but got something else — '
              'check the Response Array Key on the Endpoints tab.',
        );
      }
      final patients = list
          .whereType<Map>()
          .map((d) => _parsePatient(d, cfg, ''))
          .whereType<Patient>()
          .where((p) => p.name.isNotEmpty || p.patientId.isNotEmpty)
          .toList();
      if (patients.isEmpty) {
        return (
          patients: <Patient>[],
          error: 'Server returned zero usable patients at $uri — check the Field Map tab '
              '(Patient ID / Name mappings) against the server\'s actual JSON field names.',
        );
      }
      return (patients: patients, error: null);
    } on FormatException {
      return (patients: <Patient>[], error: 'Server response at $uri was not valid JSON.');
    } on Exception catch (e) {
      return (patients: <Patient>[], error: _friendlyError(e, uri, cfg));
    }
  }

  // ─── Test connection ──────────────────────────────────────────────────────────

  Future<({bool ok, String message})> testConnection(HisConfig cfg) async {
    if (!cfg.isConfigured) {
      return (ok: false, message: 'Server URL is empty');
    }
    final uri = _buildUri(cfg, cfg.listEndpoint);
    try {
      final response = await _httpGet(cfg, uri, const Duration(seconds: 8));
      final code = response.statusCode;
      if (code >= 200 && code < 300) {
        return (ok: true, message: 'Connected — server reachable (HTTP $code) at $uri');
      }
      switch (code) {
        case 401:
          return (ok: false, message: 'Reached server, but authentication failed (401) — check credentials.');
        case 403:
          return (ok: false, message: 'Reached server, but access denied (403) — check permissions.');
        case 404:
          return (ok: false, message: 'Server reachable, but endpoint not found (404) at $uri — check the endpoint path on the Endpoints tab.');
        default:
          return (ok: false, message: 'Server returned HTTP $code at $uri.');
      }
    } on Exception catch (e) {
      return (ok: false, message: _friendlyError(e, uri, cfg));
    }
  }

  String _friendlyError(Object e, Uri uri, HisConfig cfg) {
    final msg = e.toString();
    if (msg.contains('HandshakeException') || msg.contains('CERTIFICATE')) {
      if (cfg.allowSelfSignedCert) {
        return 'TLS handshake failed even with self-signed certs allowed — the server may not be speaking HTTPS on this port, or is unreachable.';
      }
      return 'HTTPS certificate not trusted (common on hospital-internal servers). '
          'Turn on "Allow self-signed certificate" on the Connection tab and test again.';
    }
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup')) {
      return 'Cannot reach $uri — check the URL, port, and that this PC is on the hospital network (VPN/firewall?).';
    }
    if (msg.contains('TimeoutException')) {
      return 'Connection to $uri timed out — the server did not respond in time.';
    }
    if (msg.contains('FormatException')) {
      return 'The server URL is not a valid address.';
    }
    return 'Connection error: $msg';
  }
}
