import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/app_theme.dart';
import '../../models/patient.dart';
import '../../models/print_record.dart';
import 'base_dialog.dart';

class PatientDetailDialog extends StatelessWidget {
  final Patient? patient;
  final PrintRecord? printRecord;

  const PatientDetailDialog({super.key, this.patient, this.printRecord});

  factory PatientDetailDialog.fromPrintRecord(PrintRecord r) =>
      PatientDetailDialog(printRecord: r);

  factory PatientDetailDialog.fromPatient(Patient p) =>
      PatientDetailDialog(patient: p);

  String get _name => patient?.name ?? printRecord?.name ?? '';
  String get _id => patient?.patientId ?? printRecord?.patientId ?? '';
  String get _gender => patient?.gender ?? printRecord?.gender ?? '';
  String get _dob => patient?.dateOfBirth ?? printRecord?.dateOfBirth ?? '';
  String get _blood => patient?.bloodType ?? printRecord?.bloodType ?? '';
  String get _allergy => patient?.allergy ?? printRecord?.allergy ?? '';
  String get _dept => patient?.department ?? printRecord?.department ?? '';
  String get _doctor => patient?.doctor ?? printRecord?.doctor ?? '';
  String get _admission => patient?.admissionTime ?? printRecord?.admissionTime ?? '';

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.patientDetail,
      icon: Icons.person_rounded,
      width: 500,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('ID: $_id', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (printRecord != null) ...[
                        const SizedBox(height: 2),
                        Text('EPC: ${printRecord!.epcCode}', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontFamily: 'monospace')),
                      ],
                    ],
                  ),
                ),
                if (_blood.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bloodType.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_blood, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Info grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoTile(label: S.gender, value: _gender, icon: _gender == 'Male' ? Icons.male_rounded : Icons.female_rounded),
              _InfoTile(label: S.dateOfBirth, value: _dob, icon: Icons.cake_rounded),
              _InfoTile(label: S.department, value: _dept, icon: Icons.local_hospital_rounded),
              _InfoTile(label: S.doctor, value: _doctor, icon: Icons.medical_services_rounded),
              _InfoTile(label: S.admissionTime, value: _admission, icon: Icons.calendar_today_rounded),
              if (printRecord != null)
                _InfoTile(label: S.printTime, value: _fmtDt(printRecord!.printTime), icon: Icons.print_rounded),
            ],
          ),
          if (_allergy.isNotEmpty && _allergy != 'None') ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.allergyColor.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, size: 18, color: AppColors.allergyColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${S.allergy}: $_allergy',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.allergyColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (printRecord != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.contentBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RFID Codes', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  _CodeRow(label: 'EPC', value: printRecord!.epcCode),
                  const SizedBox(height: 4),
                  _CodeRow(label: 'TID', value: printRecord!.tidCode),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        ElevatedButton(onPressed: () => Navigator.pop(context), child: Text(S.ok)),
      ],
    );
  }

  String _fmtDt(DateTime dt) =>
      '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Container(
      width: 210,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.contentBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accentBlue),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textPrimary), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeRow extends StatelessWidget {
  final String label;
  final String value;
  const _CodeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 32, child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary))),
        const SizedBox(width: 6),
        Expanded(child: Text(value, style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontFamily: 'monospace'), overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
