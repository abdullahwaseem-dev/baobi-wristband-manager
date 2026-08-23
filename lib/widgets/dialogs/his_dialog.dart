import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../models/his_config.dart';
import '../../services/his_service.dart';
import '../../services/settings_service.dart';
import '../../state/app_state.dart';
import 'base_dialog.dart' show showSuccess, showError;

class HisDialog extends StatefulWidget {
  const HisDialog({super.key});
  @override
  State<HisDialog> createState() => _HisDialogState();
}

class _HisDialogState extends State<HisDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late HisConfig _cfg;
  bool _testing = false;
  bool _saving = false;
  String _testResult = '';
  bool _testOk = false;
  bool _obscurePw = true;
  bool _obscureToken = true;
  late bool _allowSelfSigned;

  // Controllers — Connection
  late TextEditingController _urlCtrl;
  late TextEditingController _departmentCtrl;
  // Auth
  late TextEditingController _userCtrl;
  late TextEditingController _pwCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _apiKeyHeaderCtrl;
  // Endpoints
  late TextEditingController _searchEpCtrl;
  late TextEditingController _listEpCtrl;
  late TextEditingController _searchKeyCtrl;
  late TextEditingController _listKeyCtrl;
  // Field mapping
  late TextEditingController _fIdCtrl;
  late TextEditingController _fNameCtrl;
  late TextEditingController _fGenderCtrl;
  late TextEditingController _fDobCtrl;
  late TextEditingController _fBloodCtrl;
  late TextEditingController _fDeptCtrl;
  late TextEditingController _fDrCtrl;
  late TextEditingController _fAllergyCtrl;
  late TextEditingController _fAdmCtrl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _cfg = SettingsService.instance.hisConfig;
    _allowSelfSigned   = _cfg.allowSelfSignedCert;
    _urlCtrl           = TextEditingController(text: _cfg.baseUrl);
    _departmentCtrl    = TextEditingController(text: _cfg.department);
    _userCtrl          = TextEditingController(text: _cfg.username);
    _pwCtrl            = TextEditingController(text: _cfg.password);
    _tokenCtrl         = TextEditingController(text: _cfg.bearerToken);
    _apiKeyCtrl        = TextEditingController(text: _cfg.apiKey);
    _apiKeyHeaderCtrl  = TextEditingController(text: _cfg.apiKeyHeader);
    _searchEpCtrl      = TextEditingController(text: _cfg.searchEndpoint);
    _listEpCtrl        = TextEditingController(text: _cfg.listEndpoint);
    _searchKeyCtrl     = TextEditingController(text: _cfg.searchResponseKey);
    _listKeyCtrl       = TextEditingController(text: _cfg.listArrayKey);
    _fIdCtrl           = TextEditingController(text: _cfg.fPatientId);
    _fNameCtrl         = TextEditingController(text: _cfg.fName);
    _fGenderCtrl       = TextEditingController(text: _cfg.fGender);
    _fDobCtrl          = TextEditingController(text: _cfg.fDateOfBirth);
    _fBloodCtrl        = TextEditingController(text: _cfg.fBloodType);
    _fDeptCtrl         = TextEditingController(text: _cfg.fDepartment);
    _fDrCtrl           = TextEditingController(text: _cfg.fDoctor);
    _fAllergyCtrl      = TextEditingController(text: _cfg.fAllergy);
    _fAdmCtrl          = TextEditingController(text: _cfg.fAdmissionTime);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in [
      _urlCtrl, _departmentCtrl, _userCtrl, _pwCtrl, _tokenCtrl, _apiKeyCtrl,
      _apiKeyHeaderCtrl, _searchEpCtrl, _listEpCtrl, _searchKeyCtrl, _listKeyCtrl,
      _fIdCtrl, _fNameCtrl, _fGenderCtrl, _fDobCtrl, _fBloodCtrl,
      _fDeptCtrl, _fDrCtrl, _fAllergyCtrl, _fAdmCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  HisConfig _buildConfig() => _cfg.copyWith(
    baseUrl:        _urlCtrl.text.trim(),
    allowSelfSignedCert: _allowSelfSigned,
    department:     _departmentCtrl.text.trim(),
    username:       _userCtrl.text.trim(),
    password:       _pwCtrl.text,
    bearerToken:    _tokenCtrl.text.trim(),
    apiKey:         _apiKeyCtrl.text.trim(),
    apiKeyHeader:   _apiKeyHeaderCtrl.text.trim(),
    searchEndpoint: _searchEpCtrl.text.trim(),
    listEndpoint:   _listEpCtrl.text.trim(),
    searchResponseKey: _searchKeyCtrl.text.trim(),
    listArrayKey:   _listKeyCtrl.text.trim(),
    fPatientId:     _fIdCtrl.text.trim(),
    fName:          _fNameCtrl.text.trim(),
    fGender:        _fGenderCtrl.text.trim(),
    fDateOfBirth:   _fDobCtrl.text.trim(),
    fBloodType:     _fBloodCtrl.text.trim(),
    fDepartment:    _fDeptCtrl.text.trim(),
    fDoctor:        _fDrCtrl.text.trim(),
    fAllergy:       _fAllergyCtrl.text.trim(),
    fAdmissionTime: _fAdmCtrl.text.trim(),
  );

  Future<void> _test() async {
    setState(() { _testing = true; _testResult = ''; });
    final cfg = _buildConfig();
    final result = await HisService.instance.testConnection(cfg);
    setState(() {
      _testing   = false;
      _testOk    = result.ok;
      _testResult = result.message;
    });
  }

  Future<void> _save() async {
    final appState = context.read<AppState>(); // captured before any await
    final cfg = _buildConfig();
    setState(() { _cfg = cfg; _saving = true; });
    await SettingsService.instance.setHisConfig(cfg);

    // Immediately pull every patient from HIS so the Patient List fills in
    // without a separate manual step — closes the loop between "HIS saved"
    // and "patients actually visible in the app".
    final result = await appState.batchSyncFromHis('');
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);

    if (result.count > 0) {
      showSuccess(context, '${result.count} patient(s) synced from HIS into the Patient List.');
    } else {
      showError(context, result.error ?? 'HIS settings saved, but no patients were synced.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: 700,
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                _buildTabs(),
                SizedBox(
                  height: 360,
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _connectionTab(),
                      _authTab(),
                      _endpointsTab(),
                      _fieldMappingTab(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.hub_rounded, color: AppColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(S.hisConnectionTitle,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(S.hisConnectionSubtitle,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ]),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    ),
  );

  Widget _buildTabs() => Container(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
    ),
    child: TabBar(
      controller: _tab,
      labelColor: AppColors.primaryBlue,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primaryBlue,
      indicatorWeight: 2,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tabs: [
        Tab(text: S.hisTabConnection),
        Tab(text: S.hisTabAuth),
        Tab(text: S.hisTabEndpoints),
        Tab(text: S.hisTabMapping),
      ],
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.glassBorder)),
    ),
    child: Row(
      children: [
        // Test result badge
        if (_testResult.isNotEmpty) ...[
          Icon(
            _testOk ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 14,
            color: _testOk ? AppColors.successGreen : AppColors.errorRed,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _testResult,
              style: TextStyle(
                fontSize: 11,
                color: _testOk ? AppColors.successGreen : AppColors.errorRed,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        const Spacer(),
        // Test button
        OutlinedButton.icon(
          onPressed: (_testing || _saving) ? null : _test,
          icon: _testing
              ? SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue))
              : Icon(Icons.wifi_tethering_rounded, size: 14, color: AppColors.accentBlue),
          label: Text(S.hisTestConnection,
              style: TextStyle(fontSize: 12, color: AppColors.accentBlue)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
        const SizedBox(width: 10),
        // Save button — also triggers an immediate "sync all patients" so the
        // Patient List fills in right away instead of requiring a second step.
        ElevatedButton.icon(
          onPressed: (_testing || _saving) ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save_rounded, size: 14),
          label: Text(_saving ? 'Saving & syncing…' : S.save),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ],
    ),
  );

  // ─── Tab 1: Connection ────────────────────────────────────────────────────────

  Widget _connectionTab() => _tabPad(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(S.hisServerUrl),
      _field(_urlCtrl, 'http://192.168.1.100:8080/api',
          icon: Icons.dns_rounded, hint: S.hisServerUrlHint),
      const SizedBox(height: 14),
      _label(S.hisDepartment),
      _field(_departmentCtrl, 'e.g. Cardiology',
          icon: Icons.local_hospital_rounded, hint: S.hisDepartmentHint),
      const SizedBox(height: 14),
      // Self-signed HTTPS toggle — many hospital-internal servers use an
      // internal or self-signed certificate that would otherwise be rejected.
      InkWell(
        onTap: () => setState(() => _allowSelfSigned = !_allowSelfSigned),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.glassBgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Allow self-signed certificate (HTTPS)',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text('Turn this on if the hospital server uses HTTPS with an internal/untrusted certificate.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
              ]),
            ),
            Switch(
              value: _allowSelfSigned,
              onChanged: (v) => setState(() => _allowSelfSigned = v),
              activeThumbColor: AppColors.primaryBlue,
            ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      _infoBox(
        icon: Icons.info_outline_rounded,
        text: S.hisConnectionInfo,
      ),
      const SizedBox(height: 12),
      _infoBox(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.successGreen,
        text: _cfg.isConfigured ? '${S.hisConfigured}: ${_cfg.baseUrl}' : S.hisNotConfigured,
      ),
    ],
  ));

  // ─── Tab 2: Authentication ────────────────────────────────────────────────────

  Widget _authTab() => _tabPad(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(S.hisAuthType),
      _dropdown(
        value: _cfg.authType,
        items: const {
          'none':   'No Authentication',
          'basic':  'Basic Auth (Username / Password)',
          'bearer': 'Bearer Token',
          'apikey': 'API Key Header',
        },
        onChanged: (v) => setState(() => _cfg = _cfg.copyWith(authType: v)),
      ),
      const SizedBox(height: 16),
      if (_cfg.authType == 'basic') ...[
        _label(S.username),
        _field(_userCtrl, 'admin', icon: Icons.person_rounded),
        const SizedBox(height: 10),
        _label(S.password),
        _field(_pwCtrl, '••••••••', icon: Icons.lock_rounded,
            obscure: _obscurePw,
            toggle: () => setState(() => _obscurePw = !_obscurePw)),
      ],
      if (_cfg.authType == 'bearer') ...[
        _label(S.hisBearerToken),
        _field(_tokenCtrl, 'eyJhbGciOi...', icon: Icons.key_rounded,
            obscure: _obscureToken,
            toggle: () => setState(() => _obscureToken = !_obscureToken)),
      ],
      if (_cfg.authType == 'apikey') ...[
        _label(S.hisApiKeyHeader),
        _field(_apiKeyHeaderCtrl, 'X-API-Key', icon: Icons.label_rounded),
        const SizedBox(height: 10),
        _label(S.hisApiKeyValue),
        _field(_apiKeyCtrl, 'your-api-key-here', icon: Icons.vpn_key_rounded,
            obscure: _obscureToken,
            toggle: () => setState(() => _obscureToken = !_obscureToken)),
      ],
    ],
  ));

  // ─── Tab 3: Endpoints ─────────────────────────────────────────────────────────

  Widget _endpointsTab() => _tabPad(Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(S.hisSearchEndpoint),
      _field(_searchEpCtrl, '/patient/{id}', icon: Icons.search_rounded,
          hint: S.hisSearchEndpointHint),
      const SizedBox(height: 10),
      _label(S.hisSearchResponseKey),
      _field(_searchKeyCtrl, 'data   (leave empty if the patient object is the root)',
          icon: Icons.data_object_rounded, hint: S.hisSearchResponseKeyHint),
      const SizedBox(height: 16),
      _label(S.hisListEndpoint),
      _field(_listEpCtrl, '/patients', icon: Icons.list_rounded),
      const SizedBox(height: 10),
      _label(S.hisResponseKey),
      _field(_listKeyCtrl, 'data   (leave empty if root is array)',
          icon: Icons.data_object_rounded, hint: S.hisResponseKeyHint),
      const SizedBox(height: 12),
      _infoBox(
        icon: Icons.lightbulb_outline_rounded,
        color: AppColors.warningOrange,
        text: S.hisEndpointInfo,
      ),
      const SizedBox(height: 8),
      _infoBox(
        icon: Icons.info_outline_rounded,
        text: 'These two response keys are independent — a single-patient lookup and a '
            'patient list often use different JSON wrappers on the same API '
            '(e.g. single: {"result":{...}}, list: {"result":{"items":[...]}}). '
            'Use dot notation for nested keys, like "result.items".',
      ),
    ],
  ));

  // ─── Tab 4: Field Mapping ─────────────────────────────────────────────────────

  Widget _fieldMappingTab() => _tabPad(
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.hisFieldMappingInfo,
              style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 12),
          _mappingRow(S.patientId,    _fIdCtrl,      'patientId'),
          _mappingRow(S.patientName,  _fNameCtrl,    'name'),
          _mappingRow(S.gender,       _fGenderCtrl,  'gender'),
          _mappingRow(S.dateOfBirth,  _fDobCtrl,     'dateOfBirth'),
          _mappingRow(S.bloodGroup,   _fBloodCtrl,   'bloodType'),
          _mappingRow(S.department,   _fDeptCtrl,    'department'),
          _mappingRow(S.doctor,       _fDrCtrl,      'doctor'),
          _mappingRow(S.allergy,      _fAllergyCtrl, 'allergy'),
          _mappingRow(S.admissionTime,_fAdmCtrl,     'admissionTime'),
        ],
      ),
    ),
  );

  // ─── Shared helpers ───────────────────────────────────────────────────────────

  Widget _tabPad(Widget child) => Padding(
    padding: const EdgeInsets.all(20),
    child: child,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: TextStyle(color: AppColors.textSecondary, fontSize: 11,
            fontWeight: FontWeight.w600)),
  );

  Widget _field(
    TextEditingController ctrl,
    String placeholder, {
    IconData? icon,
    String? hint,
    bool obscure = false,
    VoidCallback? toggle,
  }) => TextField(
    controller: ctrl,
    obscureText: obscure,
    style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hint ?? placeholder,
      prefixIcon: icon != null ? Icon(icon, size: 16) : null,
      suffixIcon: toggle != null
          ? IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 16, color: AppColors.textMuted,
              ),
              onPressed: toggle,
            )
          : null,
    ),
  );

  Widget _dropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.glassBgInput,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.glassBorder),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        dropdownColor: AppColors.bg2,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        isExpanded: true,
        items: items.entries.map((e) => DropdownMenuItem(
          value: e.key,
          child: Text(e.value),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );

  Widget _infoBox({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final c = color ?? AppColors.accentBlue;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 8),
          Flexible(child: Text(text,
              style: TextStyle(color: c, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _mappingRow(String label, TextEditingController ctrl, String placeholder) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: placeholder,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
}

// ─── Show helper ─────────────────────────────────────────────────────────────

Future<bool> showHisDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const HisDialog(),
  );
  return result ?? false;
}
