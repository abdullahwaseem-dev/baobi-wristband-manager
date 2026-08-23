import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/his_config.dart';

class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get printSpeed => _prefs.getInt('printSpeed') ?? 14;
  Future<void> setPrintSpeed(int v) => _prefs.setInt('printSpeed', v);

  int get printDensity => _prefs.getInt('printDensity') ?? 14;
  Future<void> setPrintDensity(int v) => _prefs.setInt('printDensity', v);

  String get language => _prefs.getString('language') ?? 'en';
  Future<void> setLanguage(String v) => _prefs.setString('language', v);

  String? get _adminPasswordHash => _prefs.getString('adminPasswordHash');
  bool get hasPassword => (_adminPasswordHash ?? '').isNotEmpty;

  bool verifyPassword(String password) {
    if (!hasPassword) return true;
    return _hash(password) == _adminPasswordHash;
  }

  Future<void> setPassword(String password) =>
      _prefs.setString('adminPasswordHash', _hash(password));

  Future<void> clearPassword() => _prefs.remove('adminPasswordHash');

  String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  String get firmwareVersion => _prefs.getString('firmwareVersion') ?? 'V1.0.0';
  Future<void> setFirmwareVersion(String v) => _prefs.setString('firmwareVersion', v);

  String get wifiSSID => _prefs.getString('wifiSSID') ?? '';
  Future<void> setWifiSSID(String v) => _prefs.setString('wifiSSID', v);

  String get wifiStatus => _prefs.getString('wifiStatus') ?? 'Disconnected';
  Future<void> setWifiStatus(String v) => _prefs.setString('wifiStatus', v);

  String get hisApiUrl => _prefs.getString('hisApiUrl') ?? 'http://192.168.1.100:8080/api';
  Future<void> setHisApiUrl(String v) => _prefs.setString('hisApiUrl', v);

  HisConfig get hisConfig {
    final s = _prefs.getString('hisConfig') ?? '';
    return s.isEmpty ? const HisConfig() : HisConfig.fromJsonString(s);
  }
  Future<void> setHisConfig(HisConfig cfg) =>
      _prefs.setString('hisConfig', cfg.toJsonString());

  /// Dark / light theme preference
  bool get isDarkMode => _prefs.getBool('isDarkMode') ?? true;
  Future<void> setDarkMode(bool v) => _prefs.setBool('isDarkMode', v);

  /// Selected BB720A paper config ItemNo (e.g. 'BB720_BVP14200B')
  String get selectedPaperItemNo =>
      _prefs.getString('selectedPaperItemNo') ?? 'BB720_BVP14200B';
  Future<void> setSelectedPaperItemNo(String v) =>
      _prefs.setString('selectedPaperItemNo', v);

  /// Windows printer name (as registered in Windows Devices & Printers)
  String get printerName =>
      _prefs.getString('printerName') ?? 'BaobiPrinter BB720A';
  Future<void> setPrinterName(String v) => _prefs.setString('printerName', v);

  /// Print channel: 0 = upper, 1 = lower, 2 = printer default (SRS §BB720A channel mapping)
  int get printChannel => _prefs.getInt('printChannel') ?? 0;
  Future<void> setPrintChannel(int v) => _prefs.setInt('printChannel', v);

  // ─── Firebase cloud sync credentials ────────────────────────────────────────
  // Stored the same way HIS credentials already are (plain SharedPreferences,
  // no OS credential-vault wrapping) — a conscious, documented risk carried
  // forward from the existing pattern, not a new gap introduced here.

  String get firebaseRefreshToken => _prefs.getString('firebaseRefreshToken') ?? '';
  Future<void> setFirebaseRefreshToken(String v) => _prefs.setString('firebaseRefreshToken', v);
  Future<void> clearFirebaseRefreshToken() => _prefs.remove('firebaseRefreshToken');

  /// The signed-in Firebase Auth account's own UID, used directly as the
  /// Firestore tenant partition key (see firestore.rules) — one shared login
  /// per hospital, issued by the vendor.
  String get firebaseHospitalUid => _prefs.getString('firebaseHospitalUid') ?? '';
  Future<void> setFirebaseHospitalUid(String v) => _prefs.setString('firebaseHospitalUid', v);

  String get firebaseEmail => _prefs.getString('firebaseEmail') ?? '';
  Future<void> setFirebaseEmail(String v) => _prefs.setString('firebaseEmail', v);

  /// Firestore incremental-pull cursor for print records (avoids re-reading
  /// full history on every sync tick — a real Blaze cost concern).
  String get lastSyncedPrintTime => _prefs.getString('lastSyncedPrintTime') ?? '';
  Future<void> setLastSyncedPrintTime(String v) => _prefs.setString('lastSyncedPrintTime', v);

  /// Local SQLite print_records.id high-water mark already pushed to
  /// Firestore — the push-side counterpart to lastSyncedPrintTime above.
  int get lastPushedPrintRecordId => _prefs.getInt('lastPushedPrintRecordId') ?? 0;
  Future<void> setLastPushedPrintRecordId(int v) => _prefs.setInt('lastPushedPrintRecordId', v);
}
