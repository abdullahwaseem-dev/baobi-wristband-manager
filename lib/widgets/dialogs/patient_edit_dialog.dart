import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../models/patient.dart';
import 'base_dialog.dart';

class PatientEditDialog extends StatefulWidget {
  final Patient patient;
  const PatientEditDialog({super.key, required this.patient});

  @override
  State<PatientEditDialog> createState() => _PatientEditDialogState();
}

class _PatientEditDialogState extends State<PatientEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl    = TextEditingController(text: widget.patient.name);
  late final _idCtrl      = TextEditingController(text: widget.patient.patientId);
  late final _allergyCtrl = TextEditingController(text: widget.patient.allergy);
  late final _doctorCtrl  = TextEditingController(text: widget.patient.doctor);
  late final _dobCtrl     = TextEditingController(text: widget.patient.dateOfBirth);
  late final _admCtrl     = TextEditingController(text: widget.patient.admissionTime);
  late final _deptCtrl    = TextEditingController(text: widget.patient.department);
  late String _gender    = widget.patient.gender.isEmpty ? 'Male' : widget.patient.gender;
  late String _bloodType = widget.patient.bloodType.isEmpty ? 'A' : widget.patient.bloodType;

  @override
  void dispose() {
    _nameCtrl.dispose(); _idCtrl.dispose(); _allergyCtrl.dispose();
    _doctorCtrl.dispose(); _dobCtrl.dispose(); _admCtrl.dispose(); _deptCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl, {bool withTime = false}) async {
    DateTime? initial;
    try {
      initial = DateTime.parse(ctrl.text.replaceAll('.', '-').substring(0, 10));
    } catch (_) {
      initial = DateTime.now();
    }
    final d = await showDatePicker(
      context: context,
      initialDate: initial,
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
      setState(() => ctrl.text = '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}');
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
    final h = (t?.hour   ?? 0).toString().padLeft(2,'0');
    final m = (t?.minute ?? 0).toString().padLeft(2,'0');
    setState(() => ctrl.text =
        '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')} $h:$m');
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, widget.patient.copyWith(
      name: _nameCtrl.text.trim(),
      patientId: _idCtrl.text.trim(),
      gender: _gender,
      bloodType: _bloodType,
      allergy: _allergyCtrl.text.trim(),
      department: _deptCtrl.text.trim(),
      doctor: _doctorCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim(),
      admissionTime: _admCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.editPatient,
      icon: Icons.edit_rounded,
      width: 520,
      content: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _field(S.patientName, _nameCtrl, required: true, icon: Icons.person_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _field(S.patientId, _idCtrl, required: true, icon: Icons.badge_rounded)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _GenderSel(value: _gender, onChange: (v) => setState(() => _gender = v))),
            const SizedBox(width: 12),
            Expanded(child: _BloodSel(value: _bloodType, onChange: (v) => setState(() => _bloodType = v))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _field(S.department, _deptCtrl, icon: Icons.local_hospital_rounded)),
            const SizedBox(width: 12),
            Expanded(child: _field(S.doctor, _doctorCtrl, icon: Icons.medical_services_rounded)),
          ]),
          const SizedBox(height: 12),
          _field(S.allergy, _allergyCtrl, icon: Icons.warning_rounded),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _datePicker(S.dateOfBirth, _dobCtrl, () => _pickDate(_dobCtrl))),
            const SizedBox(width: 12),
            Expanded(child: _datePicker(S.admissionTime, _admCtrl, () => _pickDate(_admCtrl, withTime: true))),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
        ElevatedButton.icon(
          onPressed: _save,
          icon: Icon(Icons.save_rounded, size: 15),
          label: Text(S.save),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool required = false, IconData? icon}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        if (required) Text(' *', style: TextStyle(color: AppColors.errorRed, fontSize: 11)),
      ]),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          prefixIcon: icon != null ? Icon(icon, size: 15) : null,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? S.fieldRequired : null
            : null,
      ),
    ]);
  }

  Widget _datePicker(String label, TextEditingController ctrl, VoidCallback onTap) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: onTap,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
        ),
      ),
    ]);
  }
}

class _GenderSel extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _GenderSel({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(S.gender, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
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
              child: Center(child: Text(
                g == 'Male' ? S.male : S.female,
                style: TextStyle(
                  fontSize: 12,
                  color: sel ? Colors.white : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                ),
              )),
            ),
          ));
        }).toList()),
      ),
    ]);
  }
}

class _BloodSel extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChange;
  const _BloodSel({required this.value, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(S.bloodType, style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      const SizedBox(height: 5),
      Row(children: ['A', 'B', 'AB', 'O'].map((t) {
        final sel = value == t;
        final isLast = t == 'O';
        return Expanded(child: Padding(
          padding: EdgeInsets.only(right: isLast ? 0 : 5),
          child: GestureDetector(
            onTap: () => onChange(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: sel ? AppColors.bloodType.withValues(alpha: 0.2) : AppColors.glassBgInput,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? AppColors.bloodType : AppColors.glassBorder,
                    width: sel ? 1.5 : 1),
              ),
              child: Center(child: Text(t,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: sel ? AppColors.bloodType : AppColors.textSecondary,
                  ))),
            ),
          ),
        ));
      }).toList()),
    ]);
  }
}

