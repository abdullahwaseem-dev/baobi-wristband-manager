import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/dialogs/base_dialog.dart';

class PrintScreen extends StatefulWidget {
  const PrintScreen({super.key});
  @override
  State<PrintScreen> createState() => _PrintScreenState();
}

class _PrintScreenState extends State<PrintScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _idCtrl   = TextEditingController();
  final _allergyCtrl = TextEditingController();
  final _doctorCtrl  = TextEditingController();
  final _dobCtrl     = TextEditingController();
  final _admCtrl     = TextEditingController();
  final _deptCtrl    = TextEditingController();
  String _gender    = 'Male';
  String _bloodType = 'A+';
  bool   _printing  = false;
  bool   _syncing   = false;

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose(); _allergyCtrl.dispose();
    _doctorCtrl.dispose(); _dobCtrl.dispose(); _admCtrl.dispose(); _deptCtrl.dispose();
    super.dispose();
  }

  /// SRS §3.2.2 Default: Clear all input boxes and restore blank initial status
  void _default() => setState(() {
    _nameCtrl.clear(); _idCtrl.clear(); _allergyCtrl.clear();
    _doctorCtrl.clear(); _dobCtrl.clear(); _admCtrl.clear(); _deptCtrl.clear();
    _gender = 'Male'; _bloodType = 'A+';
    _formKey.currentState?.reset();
  });

  /// SRS §3.2.2 Clear: Erase all current entered content
  void _clear() => _default();

  Future<void> _pickDate(TextEditingController ctrl, {bool withTime = false}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primaryBlue, surface: Color(0xFF1E293B)),
        ),
        child: child!,
      ),
    );
    if (d == null || !mounted) return;
    if (!withTime) {
      ctrl.text = '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';
      return;
    }
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primaryBlue, surface: Color(0xFF1E293B)),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    final hour   = (t?.hour   ?? 0).toString().padLeft(2,'0');
    final minute = (t?.minute ?? 0).toString().padLeft(2,'0');
    ctrl.text = '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')} $hour:$minute';
  }

  Future<void> _syncHis() async {
    if (_idCtrl.text.trim().isEmpty) { showError(context, S.hisPullFailed); return; }
    setState(() => _syncing = true);
    final result = await context.read<AppState>().fetchFromHis(_idCtrl.text.trim());
    if (!mounted) return;
    setState(() => _syncing = false);
    final p = result.patient;
    if (p != null) {
      setState(() {
        _nameCtrl.text    = p.name;
        _allergyCtrl.text = p.allergy;
        _deptCtrl.text    = p.department;
        _doctorCtrl.text  = p.doctor;
        _dobCtrl.text     = p.dateOfBirth;
        _admCtrl.text     = p.admissionTime;
        _gender    = p.gender.isEmpty    ? 'Male' : p.gender;
        _bloodType = p.bloodType.isEmpty ? 'A+'   : p.bloodType;
      });
      showSuccess(context, S.hisPullSuccess);
    } else {
      showError(context, result.error ?? S.hisPullFailed);
    }
  }

  Future<void> _print() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _printing = true);
    final ok = await context.read<AppState>().printWristband(Patient(
      name: _nameCtrl.text.trim(), gender: _gender, patientId: _idCtrl.text.trim(),
      allergy: _allergyCtrl.text.trim(), bloodType: _bloodType,
      department: _deptCtrl.text.trim(), doctor: _doctorCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim(), admissionTime: _admCtrl.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _printing = false);
    if (ok) {
      showSuccess(context, S.printSuccess);
    } else {
      showError(context, S.printFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left: form card ─────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: GlassBox(
                blur: 25, opacity: 0.07,
                borderRadius: BorderRadius.circular(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Header
                  _CardHeader(
                    title: S.manualPrint,
                    icon: Icons.person_add_rounded,
                    trailing: OutlinedButton.icon(
                      onPressed: _syncing ? null : _syncHis,
                      icon: _syncing
                          ? SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBlue))
                          : Icon(Icons.sync_rounded, size: 14),
                      label: Text(S.syncHis, style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        foregroundColor: AppColors.accentBlue,
                        side: BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      Row(children: [
                        Expanded(child: _field(S.patientName, _nameCtrl, S.namePlaceholder,
                            required: true, icon: Icons.person_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(S.patientId, _idCtrl, S.patientIdPlaceholder,
                            required: true, icon: Icons.badge_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _GenderPicker(value: _gender, onChange: (v) => setState(() => _gender = v))),
                        const SizedBox(width: 12),
                        Expanded(child: _BloodPicker(value: _bloodType, onChange: (v) => setState(() => _bloodType = v))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _field(S.department, _deptCtrl, S.departmentPlaceholder, icon: Icons.local_hospital_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _field(S.doctor, _doctorCtrl, S.doctorPlaceholder, icon: Icons.medical_services_rounded)),
                      ]),
                      const SizedBox(height: 12),
                      _field(S.allergy, _allergyCtrl, S.allergyPlaceholder, icon: Icons.warning_rounded),
                      const SizedBox(height: 12),
                      Row(children: [
                        // Date of Birth — calendar picker
                        Expanded(child: _field(S.dateOfBirth, _dobCtrl, S.dobPlaceholder,
                            icon: Icons.cake_rounded,
                            onTap: () => _pickDate(_dobCtrl))),
                        const SizedBox(width: 12),
                        // Admission Time — calendar + time picker
                        Expanded(child: _field(S.admissionTime, _admCtrl, S.admissionPlaceholder,
                            icon: Icons.schedule_rounded,
                            onTap: () => _pickDate(_admCtrl, withTime: true))),
                      ]),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 18),
            // ── Right: preview + action buttons ──────────────────────────────
            Expanded(
              flex: 2,
              child: Column(children: [
                _WristbandPreview(
                  name: _nameCtrl.text, patientId: _idCtrl.text,
                  gender: _gender, bloodType: _bloodType,
                  allergy: _allergyCtrl.text, department: _deptCtrl.text,
                  doctor: _doctorCtrl.text, admissionTime: _admCtrl.text,
                  dateOfBirth: _dobCtrl.text,
                ),
                const SizedBox(height: 14),
                _ActionButtons(
                  onDefault: _default,
                  onClear: _clear,
                  onPrint: _printing ? null : _print,
                  printing: _printing,
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint,
      {bool required = false, IconData? icon, VoidCallback? onTap}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        if (required) Text(' *', style: TextStyle(color: AppColors.errorRed, fontSize: 11)),
      ]),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        readOnly: onTap != null,
        onTap: onTap,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, size: 15) : null,
          suffixIcon: onTap != null ? Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textMuted) : null,
        ),
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? S.fieldRequired : null : null,
      ),
    ]);
  }
}

// ─── Card Header ─────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const _CardHeader({required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 14, 13),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.glassBorder))),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: AppColors.primaryBlue.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 15, color: AppColors.accentBlue),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const Spacer(),
        ?trailing,
      ]),
    );
  }
}

// ─── Gender Picker ────────────────────────────────────────────────────────────

class _GenderPicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _GenderPicker({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(S.gender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(
          color: AppColors.glassBgInput,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(children: ['Male', 'Female'].map((g) {
          final sel = value == g;
          return Expanded(child: GestureDetector(
            onTap: () => onChange(g),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: sel ? AppColors.primaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(g == 'Male' ? Icons.male_rounded : Icons.female_rounded, size: 15,
                    color: sel ? Colors.white : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(g == 'Male' ? S.male : S.female,
                    style: TextStyle(fontSize: 12, color: sel ? Colors.white : AppColors.textSecondary,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
              ]),
            ),
          ));
        }).toList()),
      ),
    ]);
  }
}

// ─── Blood Type Picker ────────────────────────────────────────────────────────

class _BloodPicker extends StatelessWidget {
  /// Full blood type string, e.g. 'A+', 'B-', 'AB+', 'O-'
  final String value;
  final ValueChanged<String> onChange;
  const _BloodPicker({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    // Parse group and Rh from combined value
    final bool hasRh = value.endsWith('+') || value.endsWith('-');
    final String group = hasRh ? value.substring(0, value.length - 1) : value;
    final String rh    = hasRh ? value[value.length - 1] : '+';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(S.bloodType,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
      const SizedBox(height: 5),
      // ── Row 1: ABO group ────────────────────────────────────────────────
      Row(children: ['A', 'B', 'AB', 'O'].map((t) {
        final sel = group == t;
        final isLast = t == 'O';
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 6),
          child: GestureDetector(
            onTap: () => onChange('$t$rh'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel
                    ? AppColors.bloodType.withValues(alpha: 0.22)
                    : AppColors.glassBgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? AppColors.bloodType : AppColors.glassBorder,
                    width: sel ? 1.5 : 1),
              ),
              child: Center(
                child: Text(t,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sel ? AppColors.bloodType : AppColors.textSecondary)),
              ),
            ),
          ),
        ));
      }).toList()),
      const SizedBox(height: 6),
      // ── Row 2: Rh factor ────────────────────────────────────────────────
      Row(children: [
        Expanded(child: GestureDetector(
          onTap: () => onChange('$group+'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: rh == '+'
                  ? AppColors.bloodType.withValues(alpha: 0.18)
                  : AppColors.glassBgInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: rh == '+' ? AppColors.bloodType : AppColors.glassBorder,
                  width: rh == '+' ? 1.5 : 1),
            ),
            child: Center(
              child: Text('Rh +',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rh == '+' ? AppColors.bloodType : AppColors.textSecondary)),
            ),
          ),
        )),
        const SizedBox(width: 6),
        Expanded(child: GestureDetector(
          onTap: () => onChange('$group-'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: rh == '-'
                  ? AppColors.accentBlue.withValues(alpha: 0.18)
                  : AppColors.glassBgInput,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: rh == '-' ? AppColors.accentBlue : AppColors.glassBorder,
                  width: rh == '-' ? 1.5 : 1),
            ),
            child: Center(
              child: Text('Rh −',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rh == '-' ? AppColors.accentBlue : AppColors.textSecondary)),
            ),
          ),
        )),
      ]),
    ]);
  }
}

// ─── Wristband Preview ────────────────────────────────────────────────────────

class _WristbandPreview extends StatelessWidget {
  final String name, patientId, gender, bloodType, allergy, department,
      doctor, admissionTime, dateOfBirth;
  const _WristbandPreview({
    required this.name,
    required this.patientId,
    required this.gender,
    required this.bloodType,
    required this.allergy,
    required this.department,
    required this.doctor,
    required this.admissionTime,
    required this.dateOfBirth,
  });

  // Chip matching the print's _infoChip style
  Widget _chip(String label, String value, Color color) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text('$label: $value',
          style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAllergy = allergy.isNotEmpty && allergy.toLowerCase() != 'none';
    final genderLabel = gender == 'Female' ? 'F' : (gender.isNotEmpty ? 'M' : '');
    final qrData = [patientId, name, gender, bloodType, dateOfBirth,
        department, doctor, allergy, admissionTime].join('|');

    return GlassBox(
      blur: 25,
      opacity: 0.07,
      borderRadius: BorderRadius.circular(16),
      child: Column(children: [
        _CardHeader(title: 'Wristband Preview', icon: Icons.credit_card_rounded),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorderStrong),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(children: [
                // ── Left: QR (matches print — QR is placed left) ──────────
                QrImageView(
                  data: qrData.isEmpty ? 'preview' : qrData,
                  version: QrVersions.auto,
                  size: 76,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.textPrimary,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.textPrimary,
                  ),
                  backgroundColor: Colors.transparent,
                ),
                // ── Gap (matches pw.SizedBox(width: 32) in print) ────────
                const SizedBox(width: 32),
                // ── Right: patient info (same column order as print) ──────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Name
                      Text(
                        name.isEmpty ? 'Patient Name' : name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: name.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ID chip + BLD chip
                      Row(children: [
                        _chip('ID', patientId.isEmpty ? '------' : patientId,
                            AppColors.accentBlue),
                        const SizedBox(width: 4),
                        _chip('BLD', bloodType, AppColors.bloodType),
                      ]),
                      // DOB + Gender (same row, same as print)
                      if (dateOfBirth.isNotEmpty || genderLabel.isNotEmpty)
                        Row(children: [
                          if (dateOfBirth.isNotEmpty)
                            Text('DOB: $dateOfBirth',
                                style: TextStyle(
                                    fontSize: 8.5, color: AppColors.textSecondary)),
                          if (dateOfBirth.isNotEmpty && genderLabel.isNotEmpty)
                            const SizedBox(width: 8),
                          if (genderLabel.isNotEmpty)
                            Text('Gender: $genderLabel',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: gender == 'Female'
                                        ? Colors.pink.shade300
                                        : Colors.lightBlue.shade300)),
                        ]),
                      // Dept chip + Dr chip
                      Row(children: [
                        _chip('Dept', department, AppColors.primaryBlue),
                        const SizedBox(width: 4),
                        _chip('Dr', doctor, AppColors.successGreen),
                      ]),
                      // Allergy (if present)
                      if (hasAllergy)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.allergyColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('ALLERGY: $allergy',
                              style: TextStyle(
                                  fontSize: 8, color: AppColors.allergyColor,
                                  fontWeight: FontWeight.w700)),
                        ),
                      // Admission time
                      Text(
                        admissionTime.isEmpty ? '--.--.--' : admissionTime,
                        style: TextStyle(fontSize: 8.5, color: AppColors.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                ),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Text(
            'BB720A · 110×29 mm · QR left · info right · Direct Thermal',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ),
      ]),
    );
  }
}

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final VoidCallback onDefault, onClear;
  final VoidCallback? onPrint;
  final bool printing;
  const _ActionButtons({required this.onDefault, required this.onClear, required this.onPrint, required this.printing});

  @override
  Widget build(BuildContext context) {
    return GlassBox(blur: 25, opacity: 0.07, borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(16), child: Column(children: [
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPrint,
          icon: printing
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.print_rounded, size: 18),
          label: Text(printing ? 'Printing...' : S.printBtn, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            shadowColor: AppColors.primaryGlow,
            elevation: 8,
          ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton.icon(
          onPressed: onDefault, icon: Icon(Icons.restart_alt_rounded, size: 15), label: Text(S.defaultBtn),
        )),
        const SizedBox(width: 10),
        Expanded(child: OutlinedButton.icon(
          onPressed: onClear, icon: Icon(Icons.clear_all_rounded, size: 15), label: Text(S.clearBtn),
        )),
      ]),
    ]));
  }
}
