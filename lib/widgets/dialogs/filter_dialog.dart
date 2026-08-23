import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import 'base_dialog.dart';

/// Reusable filter dialog used by Patient List and Print Queue screens.
/// Returns a [FilterResult] or null if dismissed.
class FilterResult {
  final String department;
  final String gender;
  final String bloodType;
  final String dateFrom;
  final String dateTo;

  const FilterResult({
    this.department = '',
    this.gender = '',
    this.bloodType = '',
    this.dateFrom = '',
    this.dateTo = '',
  });

  bool get isEmpty =>
      department.isEmpty && gender.isEmpty && bloodType.isEmpty &&
      dateFrom.isEmpty && dateTo.isEmpty;
}

class FilterDialog extends StatefulWidget {
  final FilterResult initial;
  final bool showBloodType;
  final bool showGender;

  const FilterDialog({
    super.key,
    this.initial = const FilterResult(),
    this.showBloodType = true,
    this.showGender = true,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  final _deptCtrl     = TextEditingController();
  final _dateFromCtrl = TextEditingController();
  final _dateToCtrl   = TextEditingController();
  String _gender    = '';
  String _bloodType = '';

  @override
  void initState() {
    super.initState();
    _deptCtrl.text     = widget.initial.department;
    _dateFromCtrl.text = widget.initial.dateFrom;
    _dateToCtrl.text   = widget.initial.dateTo;
    _gender    = widget.initial.gender;
    _bloodType = widget.initial.bloodType;
  }

  @override
  void dispose() {
    _deptCtrl.dispose();
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primaryBlue,
            surface: Color(0xFF1E293B),
          ),
        ),
        child: child!,
      ),
    );
    if (d == null || !mounted) return;
    setState(() {
      ctrl.text = '${d.year}.${d.month.toString().padLeft(2,'0')}.${d.day.toString().padLeft(2,'0')}';
    });
  }

  void _apply() => Navigator.pop(context, FilterResult(
    department: _deptCtrl.text.trim(),
    gender: _gender,
    bloodType: _bloodType,
    dateFrom: _dateFromCtrl.text.trim(),
    dateTo: _dateToCtrl.text.trim(),
  ));

  void _reset() => setState(() {
    _deptCtrl.clear(); _dateFromCtrl.clear(); _dateToCtrl.clear();
    _gender = ''; _bloodType = '';
  });

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.filter,
      icon: Icons.filter_list_rounded,
      width: 440,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(S.department),
          const SizedBox(height: 5),
          TextField(
            controller: _deptCtrl,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(hintText: S.departmentPlaceholder, prefixIcon: Icon(Icons.local_hospital_rounded, size: 15)),
          ),
          if (widget.showGender) ...[
            const SizedBox(height: 14),
            _label(S.gender),
            const SizedBox(height: 8),
            _ChipRow(
              options: const ['', 'Male', 'Female'],
              labels: [S.all, S.male, S.female],
              selected: _gender,
              onSelect: (v) => setState(() => _gender = v),
            ),
          ],
          if (widget.showBloodType) ...[
            const SizedBox(height: 14),
            _label(S.bloodType),
            const SizedBox(height: 8),
            _ChipRow(
              options: const ['', 'A', 'B', 'AB', 'O'],
              labels: [S.all, 'A', 'B', 'AB', 'O'],
              selected: _bloodType,
              onSelect: (v) => setState(() => _bloodType = v),
              chipColor: AppColors.bloodType,
            ),
          ],
          const SizedBox(height: 14),
          _label('${S.admissionTime} (${S.dateFrom} → ${S.dateTo})'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _DateField(ctrl: _dateFromCtrl, hint: S.dateFrom, onTap: () => _pickDate(_dateFromCtrl))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('—', style: TextStyle(color: AppColors.textMuted))),
            Expanded(child: _DateField(ctrl: _dateToCtrl, hint: S.dateTo, onTap: () => _pickDate(_dateToCtrl))),
          ]),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: _reset,
          icon: Icon(Icons.clear_all_rounded, size: 15),
          label: Text(S.clearBtn),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
        ),
        ElevatedButton.icon(
          onPressed: _apply,
          icon: Icon(Icons.check_rounded, size: 15),
          label: Text(S.applyFilter),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary));
}

class _ChipRow extends StatelessWidget {
  final List<String> options, labels;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color chipColor;

  _ChipRow({
    required this.options, required this.labels, required this.selected,
    required this.onSelect, Color? chipColor,
  }) : chipColor = chipColor ?? AppColors.primaryBlue;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, children: List.generate(options.length, (i) {
      final sel = selected == options[i];
      return GestureDetector(
        onTap: () => onSelect(options[i]),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? chipColor.withValues(alpha: 0.2) : AppColors.glassBgInput,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? chipColor : AppColors.glassBorder, width: sel ? 1.5 : 1),
          ),
          child: Text(labels[i],
              style: TextStyle(fontSize: 12, color: sel ? chipColor : AppColors.textSecondary,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }));
  }
}

class _DateField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final VoidCallback onTap;

  const _DateField({required this.ctrl, required this.hint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      readOnly: true,
      onTap: onTap,
      style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textMuted),
      ),
    );
  }
}

