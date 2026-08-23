import 'dart:async';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/patient.dart';
import '../models/print_record.dart';
import '../services/db_service.dart';
import '../services/settings_service.dart';
import '../services/print_service.dart';
import '../services/his_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/firebase_service.dart';
import '../models/paper_config.dart';
import '../widgets/dialogs/filter_dialog.dart';

enum AppPage { home, print, patientList, printQueue }

class AppState extends ChangeNotifier {
  final _db       = DbService.instance;
  final _settings = SettingsService.instance;
  final _uuid     = const Uuid();

  AppPage _page         = AppPage.home;
  String  _language     = 'en';
  bool    _isDarkMode   = true;
  bool    _isLoading    = false;
  String  _statusMessage= '';

  // Patient list state
  List<Patient> _patients    = [];
  int    _patientTotal       = 0;
  String _patientSearch      = '';
  FilterResult _patientFilter= const FilterResult();
  static const int _pageSize = 20;
  int _patientPage = 0;

  // Print queue state
  List<PrintRecord> _printRecords = [];
  int    _printTotal              = 0;
  String _printSearch             = '';
  FilterResult _printFilter       = const FilterResult();
  int _printPage = 0;

  // Home preview
  List<Patient>     _recentPatients     = [];
  List<PrintRecord> _recentPrintRecords = [];

  // Settings
  int  _printSpeed   = 14;
  int  _printDensity = 14;
  bool _readyToPrint = true;

  // Cloud sync state
  bool _cloudSyncing = false;
  DateTime? _lastCloudSyncAt;
  String? _cloudSyncError;
  List<String> _lastConflictNotices = [];
  Timer? _cloudSyncTimer;

  // HIS auto-sync state — guards against the periodic timer firing again
  // while a previous pull is still in flight (a slow/unreachable HIS could
  // otherwise stack up overlapping requests).
  bool _hisAutoSyncing = false;
  Timer? _hisSyncTimer;

  AppState() {
    _language    = _settings.language;
    S.lang       = _language;
    _isDarkMode  = _settings.isDarkMode;
    if (_isDarkMode) { AppColors.applyDark(); } else { AppColors.applyLight(); }
    _printSpeed  = _settings.printSpeed;
    _printDensity= _settings.printDensity;
    _loadHomeData();

    // Self-throttling background sync — the only thing that actually
    // satisfies "push once back online" for a station that prints while
    // offline and nobody touches HIS/Patient-List screens again that shift.
    // syncWithFirebase() itself checks isSignedIn and no-ops when not
    // configured, so this is always safe to start unconditionally.
    _cloudSyncTimer = Timer.periodic(const Duration(seconds: 90), (_) => syncWithFirebase());

    // Background HIS sync — keeps the roster current without staff having to
    // remember to click Sync HIS / Sync All Patients. A full HIS pull is
    // heavier than Firestore's incremental cursor-based one, so this runs far
    // less often than the Cloud Sync timer above. _autoSyncHis() itself
    // no-ops when HIS isn't configured, so safe to start unconditionally.
    _hisSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _autoSyncHis());
  }

  @override
  void dispose() {
    _cloudSyncTimer?.cancel();
    _hisSyncTimer?.cancel();
    super.dispose();
  }

  // ─── Getters ─────────────────────────────────────────────────────────────────

  AppPage get page          => _page;
  String  get language      => _language;
  bool    get isDarkMode    => _isDarkMode;
  bool    get isLoading     => _isLoading;
  String  get statusMessage => _statusMessage;

  List<Patient>     get patients          => _patients;
  List<PrintRecord> get printRecords      => _printRecords;
  List<Patient>     get recentPatients    => _recentPatients;
  List<PrintRecord> get recentPrintRecords=> _recentPrintRecords;

  int    get patientTotal      => _patientTotal;
  int    get totalPatientCount => _patientTotal;
  int    get patientPage       => _patientPage;
  bool   get hasMorePatients   => (_patientPage + 1) * _pageSize < _patientTotal;
  String get searchQuery       => _patientSearch;

  int    get printTotal       => _printTotal;
  int    get totalPrintCount  => _printTotal;
  int    get printPage        => _printPage;
  bool   get hasMorePrints    => (_printPage + 1) * _pageSize < _printTotal;
  String get printSearchQuery => _printSearch;
  int    get pendingPrintCount=> _printTotal;

  int get printSpeed   => _printSpeed;
  int get printDensity => _printDensity;
  bool get readyToPrint=> _readyToPrint;

  String get wifiSSID       => _settings.wifiSSID;
  String get wifiStatus     => _settings.wifiStatus;
  String get firmwareVersion=> _settings.firmwareVersion;

  PaperConfig get paperConfig => PaperConfig.byItemNo(_settings.selectedPaperItemNo);
  String get selectedPaperItemNo => _settings.selectedPaperItemNo;
  String get printerName     => _settings.printerName;

  // ─── Cloud sync ──────────────────────────────────────────────────────────────

  bool   get isCloudSignedIn    => FirebaseAuthService.instance.isSignedIn;
  String get cloudEmail         => FirebaseAuthService.instance.signedInEmail;
  bool   get isCloudSyncing     => _cloudSyncing;
  DateTime? get lastCloudSyncAt => _lastCloudSyncAt;
  String? get cloudSyncError    => _cloudSyncError;
  List<String> get lastConflictNotices => _lastConflictNotices;
  int    get printChannel    => _settings.printChannel;

  // ─── Navigation ──────────────────────────────────────────────────────────────

  void navigate(AppPage p) {
    _page = p;
    if (p == AppPage.patientList) _loadPatients();
    if (p == AppPage.printQueue)  _loadPrintRecords();
    notifyListeners();
  }

  // ─── Language ────────────────────────────────────────────────────────────────

  Future<void> setLanguage(String lang) async {
    _language = lang;
    S.lang    = lang;
    await _settings.setLanguage(lang);
    notifyListeners();
  }

  // ─── Theme ───────────────────────────────────────────────────────────────────

  Future<void> setDarkMode(bool dark) async {
    _isDarkMode = dark;
    if (dark) { AppColors.applyDark(); } else { AppColors.applyLight(); }
    await _settings.setDarkMode(dark);
    notifyListeners();
  }

  // ─── Settings ────────────────────────────────────────────────────────────────

  Future<void> setPrintSpeed(int v) async {
    _printSpeed = v;
    await _settings.setPrintSpeed(v);
    notifyListeners();
  }

  Future<void> setPrintDensity(int v) async {
    _printDensity = v;
    await _settings.setPrintDensity(v);
    notifyListeners();
  }

  Future<void> setPaperConfig(String itemNo) async {
    await _settings.setSelectedPaperItemNo(itemNo);
    notifyListeners();
  }

  Future<void> setPrinterName(String name) async {
    await _settings.setPrinterName(name);
    notifyListeners();
  }

  Future<void> setPrintChannel(int channel) async {
    await _settings.setPrintChannel(channel);
    notifyListeners();
  }

  Future<void> connectWifi(String ssid, String password) async {
    await _settings.setWifiSSID(ssid);
    await _settings.setWifiStatus('Connected: $ssid');
    _readyToPrint = true;
    notifyListeners();
  }

  // ─── Home ─────────────────────────────────────────────────────────────────────

  Future<void> _loadHomeData() async {
    _recentPatients     = await _db.getPatients(limit: 5);
    _recentPrintRecords = await _db.getRecentPrintRecords(limit: 5);
    _printTotal         = await _db.getPrintRecordCount();
    notifyListeners();
  }

  // ─── Patient List ─────────────────────────────────────────────────────────────

  /// Public entry-point: called by screen on initState.
  Future<void> loadPatients() => _loadPatients();

  Future<void> _loadPatients() async {
    _isLoading = true;
    notifyListeners();
    _patients = await _db.getPatients(
      search: _patientSearch.isEmpty ? null : _patientSearch,
      limit:  _pageSize,
      offset: _patientPage * _pageSize,
    );
    _patients = _applyPatientFilter(_patients, _patientFilter);
    _patientTotal = await _db.getPatientCount(
      search: _patientSearch.isEmpty ? null : _patientSearch,
    );
    _isLoading = false;
    notifyListeners();
  }

  List<Patient> _applyPatientFilter(List<Patient> list, FilterResult f) {
    if (f.isEmpty) return list;
    return list.where((p) {
      if (f.gender.isNotEmpty    && p.gender    != f.gender)    return false;
      if (f.bloodType.isNotEmpty && p.bloodType != f.bloodType) return false;
      if (f.department.isNotEmpty && !p.department.toLowerCase().contains(f.department.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Future<void> searchPatients(String query, {FilterResult? filter}) async {
    _patientSearch = query;
    if (filter != null) _patientFilter = filter;
    _patientPage   = 0;
    await _loadPatients();
  }

  Future<void> addPatient(Patient p) async {
    await _db.insertPatient(p);
    await _loadPatients();
    await _loadHomeData();
  }

  Future<void> updatePatient(Patient p) async {
    await _db.updatePatient(p);
    await _loadPatients();
  }

  Future<void> deletePatient(int id) async {
    await _db.deletePatient(id);
    await _loadPatients();
    await _loadHomeData();
  }

  Future<void> nextPatientPage() async {
    if (hasMorePatients) {
      _patientPage++;
      await _loadPatients();
    }
  }

  Future<void> prevPatientPage() async {
    if (_patientPage > 0) {
      _patientPage--;
      await _loadPatients();
    }
  }

  // ─── Excel Import / Export ────────────────────────────────────────────────────

  /// SRS §7 — Import patients from .xlsx file
  Future<bool> importFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,   // required on Windows to get bytes
      );
      if (result == null || result.files.isEmpty) return false;

      final picked = result.files.first;
      late List<int> bytes;
      if (picked.bytes != null && picked.bytes!.isNotEmpty) {
        bytes = picked.bytes!;
      } else if (picked.path != null) {
        bytes = await File(picked.path!).readAsBytes();
      } else {
        return false;
      }

      final workbook = Excel.decodeBytes(bytes);

      final patients = <Patient>[];
      for (final sheet in workbook.tables.values) {
        // Find header row index (first non-empty row)
        final startRow = sheet.maxRows > 0 ? 1 : 0;
        for (int row = startRow; row < sheet.maxRows; row++) {
          final cells = sheet.row(row);
          String cell(int i) {
            if (i >= cells.length) return '';
            final v = cells[i]?.value;
            if (v == null) return '';
            if (v is TextCellValue)   return v.value.toString().trim();
            if (v is IntCellValue)    return v.value.toString();
            if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
            if (v is DateCellValue)   return v.asDateTimeUtc().toLocal().toString().split(' ').first;
            return v.toString().trim();
          }
          if (cell(0).isEmpty && cell(1).isEmpty) continue;
          patients.add(Patient(
            name:          cell(0),
            patientId:     cell(1),
            gender:        cell(2).isEmpty ? 'Male' : cell(2),
            dateOfBirth:   cell(3),
            department:    cell(4),
            bloodType:     cell(5).isEmpty ? 'A+' : cell(5),
            allergy:       cell(6),
            admissionTime: cell(7),
            doctor:        cell(8),
            // Bulk/automatic source, not a local UI edit — a re-import of an
            // updated spreadsheet must be free to refresh these rows again.
            dirty: false,
          ));
        }
      }
      if (patients.isEmpty) return false;
      await _db.batchInsertPatients(patients);
      await _loadPatients();
      await _loadHomeData();
      return true;
    } catch (e) {
      debugPrint('importFromExcel error: $e');
      return false;
    }
  }

  /// SRS §7 — Export patients to .xlsx file
  Future<bool> exportToExcel() async {
    try {
      final allPatients = await _db.getAllPatients();
      final excel      = Excel.createExcel();
      final sheet      = excel['Patients'];

      // Header row
      final headers = ['Name', 'Patient ID', 'Gender', 'Date of Birth',
          'Department', 'Blood Type', 'Allergy', 'Admission Time', 'Doctor'];
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
            .value = TextCellValue(headers[i]);
      }
      // Data rows
      for (int r = 0; r < allPatients.length; r++) {
        final p = allPatients[r];
        final rowData = [p.name, p.patientId, p.gender, p.dateOfBirth,
            p.department, p.bloodType, p.allergy, p.admissionTime, p.doctor];
        for (int c = 0; c < rowData.length; c++) {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
              .value = TextCellValue(rowData[c]);
        }
      }

      final dir     = await getApplicationDocumentsDirectory();
      final ts      = DateTime.now();
      final fname   = 'baobi_patients_${ts.year}${ts.month.toString().padLeft(2,'0')}${ts.day.toString().padLeft(2,'0')}.xlsx';
      final file    = File('${dir.path}/$fname');
      final encoded = excel.encode();
      if (encoded == null) return false;
      await file.writeAsBytes(encoded);
      return true;
    } catch (e) {
      debugPrint('exportToExcel error: $e');
      return false;
    }
  }

  // ─── Print Queue ──────────────────────────────────────────────────────────────

  /// Public entry-point: called by screen on initState.
  Future<void> loadPrintRecords() => _loadPrintRecords();

  Future<void> _loadPrintRecords() async {
    _isLoading = true;
    notifyListeners();
    _printRecords = await _db.getPrintRecords(
      search: _printSearch.isEmpty ? null : _printSearch,
      limit:  _pageSize,
      offset: _printPage * _pageSize,
    );
    _printRecords = _applyPrintFilter(_printRecords, _printFilter);
    _printTotal   = await _db.getPrintRecordCount(
      search: _printSearch.isEmpty ? null : _printSearch,
    );
    _isLoading = false;
    notifyListeners();
  }

  List<PrintRecord> _applyPrintFilter(List<PrintRecord> list, FilterResult f) {
    if (f.isEmpty) return list;
    return list.where((r) {
      if (f.department.isNotEmpty && !r.department.toLowerCase().contains(f.department.toLowerCase())) {
        return false;
      }
      if (f.dateFrom.isNotEmpty) {
        final from = DateTime.tryParse(f.dateFrom.replaceAll('.', '-'));
        if (from != null && r.printTime.isBefore(from)) return false;
      }
      if (f.dateTo.isNotEmpty) {
        final to = DateTime.tryParse(f.dateTo.replaceAll('.', '-'));
        if (to != null && r.printTime.isAfter(to.add(const Duration(days: 1)))) return false;
      }
      return true;
    }).toList();
  }

  Future<void> searchPrintRecords(String query, {FilterResult? filter}) async {
    _printSearch = query;
    if (filter != null) _printFilter = filter;
    _printPage   = 0;
    await _loadPrintRecords();
  }

  Future<void> nextPrintPage() async {
    if (hasMorePrints) {
      _printPage++;
      await _loadPrintRecords();
    }
  }

  Future<void> prevPrintPage() async {
    if (_printPage > 0) {
      _printPage--;
      await _loadPrintRecords();
    }
  }

  // ─── Print Wristband ─────────────────────────────────────────────────────────

  Future<bool> printWristband(Patient patient) async {
    final epcCode = 'EPC-${_uuid.v4().substring(0, 12).toUpperCase()}';
    final tidCode = 'TID-${_uuid.v4().substring(0, 12).toUpperCase()}';

    final existing = await _db.getPatientByPatientId(patient.patientId);
    if (existing == null) {
      await _db.insertPatient(patient);
    } else {
      await _db.updatePatient(patient.copyWith(id: existing.id));
    }

    final record = PrintRecord(
      name: patient.name, patientId: patient.patientId,
      gender: patient.gender, dateOfBirth: patient.dateOfBirth,
      bloodType: patient.bloodType, allergy: patient.allergy,
      department: patient.department, doctor: patient.doctor,
      admissionTime: patient.admissionTime,
      epcCode: epcCode, tidCode: tidCode,
    );
    await _db.insertPrintRecord(record);

    final success = await PrintService.instance.printWristband(patient);

    await _loadHomeData();
    if (_page == AppPage.printQueue)  await _loadPrintRecords();
    if (_page == AppPage.patientList) await _loadPatients();

    // Fire-and-forget: push this print to the cloud promptly rather than
    // waiting up to 90s for the next periodic tick, without making the print
    // flow itself wait on a network round trip. The periodic timer remains
    // the safety net if this device is offline right now.
    if (FirebaseAuthService.instance.isSignedIn) {
      unawaited(syncWithFirebase());
    }

    return success;
  }

  // ─── HIS Sync ────────────────────────────────────────────────────────────────

  /// Tries the hospital's own HIS first (this button's primary purpose).
  /// If HIS doesn't have the patient, falls back to a single cheap Firestore
  /// doc lookup — e.g. a walk-in already added at another station and pushed
  /// to the cloud, but not yet present in the HIS. Deliberately never
  /// triggers a full-roster pull; that would turn a one-field lookup into a
  /// full collection read on every click.
  Future<({Patient? patient, String? error})> fetchFromHis(String patientId) async {
    final hisResult = await HisService.instance.fetchPatientById(patientId);
    if (hisResult.patient != null) return hisResult;
    if (!FirebaseAuthService.instance.isSignedIn) return hisResult;

    final cloudResult = await FirebaseService.instance.pullOnePatient(patientId);
    if (cloudResult.patient != null) return (patient: cloudResult.patient, error: null);
    return hisResult; // neither source had it — surface the HIS error/message
  }

  /// Pulls the hospital's roster from HIS, writes it locally, and — when
  /// signed in to Firebase — pushes that same data to the cloud and then
  /// pulls the full merged roster back down. This is what "Sync HIS should
  /// refresh the whole Patient List" actually means once Firebase is the
  /// shared backend: every station sees everything, not just what HIS itself
  /// returned to this one device.
  Future<({int count, String? error})> batchSyncFromHis(String ward) async {
    final result = await HisService.instance.batchSync(ward);
    var written = 0;
    if (result.patients.isNotEmpty) {
      // written may be less than result.patients.length if some rows have
      // unsynced local edits (dirty=1) and were intentionally skipped.
      written = await _db.batchInsertPatients(result.patients);

      // Freshly-pulled HIS data is deliberately NOT flagged dirty (see
      // HisService._parsePatient) so a repeated HIS sync doesn't block
      // itself out — but it still needs to reach Firestore, so push it
      // directly here rather than relying on the dirty-flag-driven path
      // used for human edits.
      if (FirebaseAuthService.instance.isSignedIn) {
        await FirebaseService.instance.pushPatients(result.patients);
      }
    }
    await _loadPatients();
    await _loadHomeData();

    // Pull the full merged roster back down so this device also picks up
    // anything other stations have added — satisfies "sync all data in the
    // patient list too, from the backend."
    if (FirebaseAuthService.instance.isSignedIn) {
      await syncWithFirebase();
    }
    return (count: written, error: result.error);
  }

  /// Periodic-timer entry point — same pull as the Save/Sync HIS/Sync All
  /// Patients buttons, just self-triggered. No-ops when HIS isn't configured,
  /// and self-throttles against overlapping calls the same way
  /// [syncWithFirebase] does, in case a previous tick's pull is still
  /// in flight when the next one fires.
  Future<void> _autoSyncHis() async {
    if (!_settings.hisConfig.isConfigured) return;
    if (_hisAutoSyncing) return;
    _hisAutoSyncing = true;
    try {
      await batchSyncFromHis('');
    } finally {
      _hisAutoSyncing = false;
    }
  }

  // ─── Cloud sync orchestration ─────────────────────────────────────────────────

  /// Push local changes up, pull the shared roster down. Safe to call
  /// anywhere, anytime — no-ops immediately if not signed in, and
  /// self-throttles against overlapping calls (the periodic timer, a manual
  /// "Refresh from Cloud" tap, and a HIS sync's follow-up pull can all fire
  /// close together without racing each other).
  Future<void> syncWithFirebase() async {
    if (!FirebaseAuthService.instance.isSignedIn) return;
    if (_cloudSyncing) return;
    _cloudSyncing = true;
    _lastConflictNotices = [];
    notifyListeners();

    try {
      String? error;

      // 1. Push locally-edited (dirty) patients.
      final dirty = await _db.getDirtyPatients();
      if (dirty.isNotEmpty) {
        final pushResult = await FirebaseService.instance.pushPatients(dirty);
        for (final p in pushResult.succeeded) {
          await _db.updatePatient(p);
        }
        for (final p in pushResult.conflicted) {
          // Remote wins: clear dirty locally so step 3's pull is free to
          // overwrite with the authoritative remote version, and tell the
          // user their change didn't silently disappear.
          await _db.updatePatient(p.copyWith(dirty: false));
          _lastConflictNotices.add('${p.name} (${p.patientId})');
        }
        error ??= pushResult.error;
      }

      // 2. Push not-yet-pushed print records (cursor-based, see DbService).
      final toPush = await _db.getPrintRecordsSinceId(_settings.lastPushedPrintRecordId);
      if (toPush.isNotEmpty) {
        final pushResult = await FirebaseService.instance.pushPrintRecords(toPush);
        final succeededIds = pushResult.succeeded.map((r) => r.id).toSet();
        var newCursor = _settings.lastPushedPrintRecordId;
        for (final r in toPush) {
          if (succeededIds.contains(r.id)) {
            newCursor = r.id!;
          } else {
            break; // stop at the first gap — never permanently skip a record
          }
        }
        if (newCursor != _settings.lastPushedPrintRecordId) {
          await _settings.setLastPushedPrintRecordId(newCursor);
        }
        error ??= pushResult.error;
      }

      // 3. Pull the full patient roster (source of truth going forward).
      final pull = await FirebaseService.instance.pullPatients();
      if (pull.error == null) {
        await _db.batchInsertPatients(pull.patients);
      } else {
        error ??= pull.error;
      }

      // 4. Pull print records since the last sync (incremental cursor).
      final pullRecords = await FirebaseService.instance.pullPrintRecords();
      if (pullRecords.error == null) {
        for (final r in pullRecords.records) {
          await _db.insertPrintRecord(r); // ConflictAlgorithm.ignore de-dupes by sync_id
        }
      } else {
        error ??= pullRecords.error;
      }

      _cloudSyncError = error;
      _lastCloudSyncAt = DateTime.now();
      await _loadPatients();
      await _loadPrintRecords();
      await _loadHomeData();
    } finally {
      _cloudSyncing = false;
      notifyListeners();
    }
  }

  void setStatus(String msg) {
    _statusMessage = msg;
    notifyListeners();
  }

  void refresh() => notifyListeners();

  // ─── Maintenance ────────────────────────────────────────────────────────────

  /// Wipes all locally stored patients and print records (e.g. demo/test data
  /// from rehearsing a HIS connection) and resets pagination/search state.
  Future<void> clearAllData() async {
    await _db.clearAllData();
    _patientSearch = '';
    _patientFilter = const FilterResult();
    _patientPage   = 0;
    _printSearch   = '';
    _printFilter   = const FilterResult();
    _printPage     = 0;
    await _loadPatients();
    await _loadPrintRecords();
    await _loadHomeData();
  }

}
