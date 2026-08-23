// ignore_for_file: avoid_print
// Mock hospital HIS server — for rehearsing the HIS Connection setup BEFORE
// going on-site, so the first time you configure it isn't in front of hospital
// staff. Run with:
//
//   dart run tool/mock_his_server.dart
//
// Then point the app's HIS Connection dialog at it (see the printed
// instructions below) and click through Test Connection -> Sync HIS exactly
// as you would at the hospital.
//
// Two scenarios are served, both with the SAME five fake patients:
//
//   /easy/...     — field names match the app's out-of-the-box defaults.
//                   Zero field mapping needed. Confirms the basic plumbing
//                   (URL, endpoints, parsing, print preview) works.
//
//   /hospital/... — deliberately awkward, like a real HIS: nested JSON,
//                   different field names, wrapped list, and requires a
//                   Bearer token. Forces you to practice the Auth tab and
//                   Field Map tab — the part you'll actually have to do live.
//
// An HTTPS variant of both is also served on a second port using a real
// (self-signed) certificate, so you can rehearse the "Allow self-signed
// certificate" toggle too, in case the hospital server turns out to be HTTPS.

import 'dart:convert';
import 'dart:io';

const httpPort  = 9090;
const httpsPort = 9443;
const bearerToken = 'demo-secret-token';

final _patients = [
  {
    'id': 'P1001', 'fullName': 'Chen Wei', 'sex': 'M', 'dob': '1985.03.12',
    'blood': 'O+', 'ward': 'Cardiology', 'doc': 'Dr. Zhang', 'allergy': 'None',
    'admitted': '2026.07.04 09:15',
  },
  {
    'id': 'P1002', 'fullName': 'Fatima Al-Sayed', 'sex': 'F', 'dob': '1990.11.02',
    'blood': 'A-', 'ward': 'Maternity', 'doc': 'Dr. Hassan', 'allergy': 'Penicillin',
    'admitted': '2026.07.04 10:40',
  },
  {
    'id': 'P1003', 'fullName': 'John Smith', 'sex': 'M', 'dob': '1958.06.30',
    'blood': 'B+', 'ward': 'Internal Medicine', 'doc': 'Dr. Lee', 'allergy': 'None',
    'admitted': '2026.07.03 22:05',
  },
  {
    'id': 'P1004', 'fullName': 'Aiko Tanaka', 'sex': 'F', 'dob': '2001.09.18',
    'blood': 'AB+', 'ward': 'Orthopedics', 'doc': 'Dr. Kimura', 'allergy': 'Latex',
    'admitted': '2026.07.05 07:50',
  },
  {
    'id': 'P1005', 'fullName': 'Ahmed Karim', 'sex': 'M', 'dob': '1975.01.25',
    'blood': 'O-', 'ward': 'Emergency', 'doc': 'Dr. Osei', 'allergy': 'None',
    'admitted': '2026.07.05 08:30',
  },
];

Map<String, dynamic>? _find(String id) {
  for (final p in _patients) {
    if (p['id'] == id) return p;
  }
  return null;
}

// ─── "Easy" scenario: field names match app defaults exactly ─────────────────

Map<String, dynamic> _easyShape(Map<String, dynamic> p) => {
  'patientId': p['id'],
  'name': p['fullName'],
  'gender': p['sex'],
  'dateOfBirth': p['dob'],
  'bloodType': p['blood'],
  'department': p['ward'],
  'doctor': p['doc'],
  'allergy': p['allergy'],
  'admissionTime': p['admitted'],
};

// ─── "Hospital" scenario: awkward, nested, wrapped, auth-gated ────────────────

Map<String, dynamic> _hospitalShape(Map<String, dynamic> p) => {
  'mrn': p['id'],
  'demographics': {
    'fullName': p['fullName'],
    'sexCode': p['sex'],
    'birthDate': p['dob'],
    'bloodGroup': p['blood'],
  },
  'encounter': {
    'ward': p['ward'],
    'attendingPhysician': p['doc'],
    'admittedAt': p['admitted'],
  },
  'allergies': p['allergy'],
};

void _log(HttpRequest req, String outcome) {
  final auth = req.headers.value('authorization');
  final authNote = auth == null ? '' : ' auth="${auth.length > 20 ? '${auth.substring(0, 20)}...' : auth}"';
  print('[${DateTime.now().toIso8601String().substring(11, 19)}] '
      '${req.method} ${req.uri.path}$authNote -> $outcome');
}

Future<void> _handle(HttpRequest req) async {
  final res = req.response;
  res.headers.contentType = ContentType.json;
  final path = req.uri.path;

  try {
    // ── Easy: GET /easy/patient/{id}  and  GET /easy/patients ──────────────
    if (path.startsWith('/easy/patient/')) {
      final id = path.split('/').last;
      final p = _find(id);
      if (p == null) {
        res.statusCode = HttpStatus.ok; // deliberately mimics a real HIS: "not found" as an empty 200
        res.write('{}');
        _log(req, 'not found (empty 200)');
      } else {
        res.write(jsonEncode(_easyShape(p)));
        _log(req, 'OK — ${p['fullName']}');
      }
      return;
    }
    if (path == '/easy/patients') {
      res.write(jsonEncode(_patients.map(_easyShape).toList()));
      _log(req, 'OK — list of ${_patients.length}');
      return;
    }

    // ── Hospital: requires Bearer token, nested JSON, wrapped list ─────────
    if (path.startsWith('/hospital/')) {
      final auth = req.headers.value('authorization');
      if (auth != 'Bearer $bearerToken') {
        res.statusCode = HttpStatus.unauthorized;
        res.write(jsonEncode({'error': 'missing or invalid bearer token'}));
        _log(req, '401 unauthorized');
        return;
      }
      if (path.startsWith('/hospital/patient/')) {
        final id = path.split('/').last;
        final p = _find(id);
        if (p == null) {
          res.statusCode = HttpStatus.notFound;
          _log(req, '404 not found');
        } else {
          res.write(jsonEncode({'result': _hospitalShape(p)}));
          _log(req, 'OK — ${p['fullName']}');
        }
        return;
      }
      if (path == '/hospital/patients') {
        res.write(jsonEncode({
          'result': {'items': _patients.map(_hospitalShape).toList()},
        }));
        _log(req, 'OK — list of ${_patients.length}');
        return;
      }
    }

    res.statusCode = HttpStatus.notFound;
    res.write(jsonEncode({'error': 'unknown path'}));
    _log(req, '404 unknown path');
  } finally {
    await res.close();
  }
}

Future<void> main() async {
  final httpServer = await HttpServer.bind(InternetAddress.anyIPv4, httpPort);
  httpServer.listen(_handle);

  HttpServer? httpsServer;
  final certFile = File('test/fixtures/test_cert.pem');
  final keyFile  = File('test/fixtures/test_key.pem');
  if (certFile.existsSync() && keyFile.existsSync()) {
    final ctx = SecurityContext()
      ..useCertificateChain(certFile.path)
      ..usePrivateKey(keyFile.path);
    httpsServer = await HttpServer.bindSecure(InternetAddress.anyIPv4, httpsPort, ctx);
    httpsServer.listen(_handle);
  }

  final lan = await _localIp();

  print('=' * 78);
  print('MOCK HOSPITAL HIS SERVER — for rehearsal only, not real patient data');
  print('=' * 78);
  print('');
  print('Running on this PC:      http://localhost:$httpPort');
  if (lan != null) {
    print('Reachable from same WiFi/LAN (use this if testing from a phone/2nd PC):');
    print('                          http://$lan:$httpPort');
  }
  if (httpsServer != null) {
    print('HTTPS (self-signed cert): https://localhost:$httpsPort');
  }
  print('');
  print('SCENARIO 1 — "Easy" (rehearse the basic plumbing, no field mapping needed)');
  print('  In the app: Home -> System Settings -> HIS Connection');
  print('  Connection tab -> Server Base URL: http://localhost:$httpPort/easy');
  print('  Auth tab       -> No Authentication');
  print('  Endpoints tab  -> Search Endpoint: /patient/{id}   List Endpoint: /patients');
  print('  Field Map tab  -> leave everything at the defaults');
  print('  Click Test Connection, then Save.');
  print('  On the Print screen, type Patient ID  P1001  and click Sync HIS.');
  print('  Try P1002 as well -> it has an allergy, so the red warning strip should appear.');
  print('  Try P9999 -> should say patient not found (this mock returns an empty');
  print('  200 response for unknown IDs, exactly like some real hospital systems do).');
  print('');
  print('SCENARIO 2 — "Hospital" (rehearse Auth + Field Map, the part that varies per site)');
  print('  This scenario deliberately uses a DIFFERENT JSON wrapper for a single patient');
  print('  than for the patient list, which is common on real hospital APIs. That is what');
  print('  the two separate "Response Key" fields on the Endpoints tab are for.');
  print('  Connection tab -> Server Base URL: http://localhost:$httpPort/hospital');
  print('  Auth tab       -> Bearer Token -> $bearerToken');
  print('  Endpoints tab  -> Search Endpoint: /patient/{id}');
  print('                    Response Key (single patient): result');
  print('                    List Endpoint: /patients');
  print('                    Response Array Key (patient list): result.items');
  print('  Field Map tab  -> Patient ID: mrn');
  print('                    Name: demographics.fullName');
  print('                    Gender: demographics.sexCode');
  print('                    Date of Birth: demographics.birthDate');
  print('                    Blood Type: demographics.bloodGroup');
  print('                    Department: encounter.ward');
  print('                    Doctor: encounter.attendingPhysician');
  print('                    Allergy: allergies');
  print('                    Admission Time: encounter.admittedAt');
  print('  Click Test Connection, then Save (this also syncs all patients into the');
  print('  Patient List), then try Sync HIS on the Print screen with P1003/P1004/P1005.');
  print('');
  if (httpsServer != null) {
    print('SCENARIO 3 — HTTPS with an untrusted certificate (rehearse the cert toggle)');
    print('  Connection tab -> Server Base URL: https://localhost:$httpsPort/easy');
    print('  Leave "Allow self-signed certificate" OFF -> Test Connection should FAIL');
    print('  with a message telling you to turn that toggle on.');
    print('  Turn it ON -> Test Connection should now succeed.');
    print('');
  }
  print('Every request the app makes will be logged below, including the exact');
  print('auth header sent — useful for spotting typos in URLs/tokens on the day.');
  print('Press Ctrl+C to stop this server.');
  print('=' * 78);
}

Future<String?> _localIp() async {
  try {
    final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  } catch (_) {}
  return null;
}
