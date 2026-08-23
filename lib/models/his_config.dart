import 'dart:convert';

class HisConfig {
  final String baseUrl;
  final String authType;     // none | basic | bearer | apikey
  final String username;
  final String password;
  final String bearerToken;
  final String apiKey;
  final String apiKeyHeader;
  final String searchEndpoint; // e.g. /patient/{id}
  final String listEndpoint;   // e.g. /patients
  final String searchResponseKey; // root key for the SINGLE-patient response, e.g. {"result":{...}}
  final String listArrayKey;   // root key for the LIST response, e.g. {"result":{"items":[...]}}
  final bool allowSelfSignedCert; // trust internal/self-signed HTTPS certs (common on hospital intranets)
  // Department VALUE sent as its own request parameter on every HIS call
  // (e.g. ?department=Cardiology), so the HIS can filter/scope patient data
  // by department. Distinct from fDepartment below, which only maps the
  // JSON key that holds a department NAME in the HIS's response.
  final String department;
  // JSON field → Patient field mappings
  final String fPatientId;
  final String fName;
  final String fGender;
  final String fDateOfBirth;
  final String fBloodType;
  final String fDepartment;
  final String fDoctor;
  final String fAllergy;
  final String fAdmissionTime;

  const HisConfig({
    this.baseUrl          = '',
    this.authType         = 'none',
    this.username         = '',
    this.password         = '',
    this.bearerToken      = '',
    this.apiKey           = '',
    this.apiKeyHeader     = 'X-API-Key',
    this.searchEndpoint   = '/patient/{id}',
    this.listEndpoint     = '/patients',
    this.searchResponseKey = '',
    this.listArrayKey     = '',
    this.allowSelfSignedCert = false,
    this.department        = '',
    this.fPatientId       = 'patientId',
    this.fName            = 'name',
    this.fGender          = 'gender',
    this.fDateOfBirth     = 'dateOfBirth',
    this.fBloodType       = 'bloodType',
    this.fDepartment      = 'department',
    this.fDoctor          = 'doctor',
    this.fAllergy         = 'allergy',
    this.fAdmissionTime   = 'admissionTime',
  });

  bool get isConfigured => baseUrl.isNotEmpty;

  static const HisConfig _defaults = HisConfig();

  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl, 'authType': authType,
    'username': username, 'password': password,
    'bearerToken': bearerToken, 'apiKey': apiKey,
    'apiKeyHeader': apiKeyHeader,
    'searchEndpoint': searchEndpoint, 'listEndpoint': listEndpoint,
    'searchResponseKey': searchResponseKey,
    'listArrayKey': listArrayKey,
    'allowSelfSignedCert': allowSelfSignedCert,
    'department': department,
    'fPatientId': fPatientId, 'fName': fName, 'fGender': fGender,
    'fDateOfBirth': fDateOfBirth, 'fBloodType': fBloodType,
    'fDepartment': fDepartment, 'fDoctor': fDoctor,
    'fAllergy': fAllergy, 'fAdmissionTime': fAdmissionTime,
  };

  factory HisConfig.fromJson(Map<String, dynamic> j) => HisConfig(
    baseUrl:        j['baseUrl']        ?? '',
    authType:       j['authType']       ?? 'none',
    username:       j['username']       ?? '',
    password:       j['password']       ?? '',
    bearerToken:    j['bearerToken']    ?? '',
    apiKey:         j['apiKey']         ?? '',
    apiKeyHeader:   j['apiKeyHeader']   ?? 'X-API-Key',
    searchEndpoint: j['searchEndpoint'] ?? '/patient/{id}',
    listEndpoint:   j['listEndpoint']   ?? '/patients',
    searchResponseKey: j['searchResponseKey'] ?? '',
    listArrayKey:   j['listArrayKey']   ?? '',
    allowSelfSignedCert: j['allowSelfSignedCert'] ?? false,
    department:     j['department']     ?? '',
    fPatientId:     j['fPatientId']     ?? 'patientId',
    fName:          j['fName']          ?? 'name',
    fGender:        j['fGender']        ?? 'gender',
    fDateOfBirth:   j['fDateOfBirth']   ?? 'dateOfBirth',
    fBloodType:     j['fBloodType']     ?? 'bloodType',
    fDepartment:    j['fDepartment']    ?? 'department',
    fDoctor:        j['fDoctor']        ?? 'doctor',
    fAllergy:       j['fAllergy']       ?? 'allergy',
    fAdmissionTime: j['fAdmissionTime'] ?? 'admissionTime',
  );

  factory HisConfig.fromJsonString(String s) {
    try { return HisConfig.fromJson(json.decode(s) as Map<String, dynamic>); }
    catch (_) { return _defaults; }
  }

  String toJsonString() => json.encode(toJson());

  HisConfig copyWith({
    String? baseUrl, String? authType, String? username, String? password,
    String? bearerToken, String? apiKey, String? apiKeyHeader,
    String? searchEndpoint, String? listEndpoint,
    String? searchResponseKey, String? listArrayKey,
    bool? allowSelfSignedCert,
    String? department,
    String? fPatientId, String? fName, String? fGender, String? fDateOfBirth,
    String? fBloodType, String? fDepartment, String? fDoctor,
    String? fAllergy, String? fAdmissionTime,
  }) => HisConfig(
    baseUrl:        baseUrl        ?? this.baseUrl,
    authType:       authType       ?? this.authType,
    username:       username       ?? this.username,
    password:       password       ?? this.password,
    bearerToken:    bearerToken    ?? this.bearerToken,
    apiKey:         apiKey         ?? this.apiKey,
    apiKeyHeader:   apiKeyHeader   ?? this.apiKeyHeader,
    searchEndpoint: searchEndpoint ?? this.searchEndpoint,
    listEndpoint:   listEndpoint   ?? this.listEndpoint,
    searchResponseKey: searchResponseKey ?? this.searchResponseKey,
    listArrayKey:   listArrayKey   ?? this.listArrayKey,
    allowSelfSignedCert: allowSelfSignedCert ?? this.allowSelfSignedCert,
    department:     department     ?? this.department,
    fPatientId:     fPatientId     ?? this.fPatientId,
    fName:          fName          ?? this.fName,
    fGender:        fGender        ?? this.fGender,
    fDateOfBirth:   fDateOfBirth   ?? this.fDateOfBirth,
    fBloodType:     fBloodType     ?? this.fBloodType,
    fDepartment:    fDepartment    ?? this.fDepartment,
    fDoctor:        fDoctor        ?? this.fDoctor,
    fAllergy:       fAllergy       ?? this.fAllergy,
    fAdmissionTime: fAdmissionTime ?? this.fAdmissionTime,
  );
}
