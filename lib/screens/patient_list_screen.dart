import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/patient.dart';
import '../state/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/dialogs/base_dialog.dart';
import '../widgets/dialogs/filter_dialog.dart';
import '../widgets/dialogs/patient_edit_dialog.dart';
import '../widgets/dialogs/add_patient_dialog.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});
  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  final _searchCtrl = TextEditingController();
  FilterResult _filter = const FilterResult();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPatients();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(AppState state) =>
      state.searchPatients(_searchCtrl.text.trim(), filter: _filter);

  Future<void> _openFilter() async {
    final result = await showDialog<FilterResult>(
      context: context,
      builder: (_) => FilterDialog(initial: _filter),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _search(context.read<AppState>());
    }
  }

  Future<void> _confirmDelete(AppState state, Patient p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => BaseDialog(
        title: S.warning,
        icon: Icons.delete_rounded,
        width: 360,
        content: Text(S.deleteConfirm, style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.cancel)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text(S.delete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await state.deletePatient(p.id!);
      if (mounted) showSuccess(context, '${p.name} deleted');
    }
  }

  Future<void> _openAdd(AppState state) async {
    final patient = await showDialog<Patient>(
      context: context,
      builder: (_) => const AddPatientDialog(),
    );
    if (patient != null && mounted) {
      await state.addPatient(patient);
      if (mounted) showSuccess(context, S.saveSuccess);
    }
  }

  Future<void> _openEdit(AppState state, Patient p) async {
    final updated = await showDialog<Patient>(
      context: context,
      builder: (_) => PatientEditDialog(patient: p),
    );
    if (updated != null && mounted) {
      await state.updatePatient(updated);
      if (mounted) showSuccess(context, S.saveSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final patients = state.patients;
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(children: [
            // ── Toolbar ────────────────────────────────────────────────────
            GlassBox(
              blur: 20, opacity: 0.07, borderRadius: BorderRadius.circular(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(children: [
                Expanded(child: TextField(
                  controller: _searchCtrl,
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  onSubmitted: (_) => _search(state),
                  decoration: InputDecoration(
                    hintText: S.searchPlaceholder,
                    prefixIcon: Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(icon: Icon(Icons.clear_rounded, size: 16),
                            onPressed: () { _searchCtrl.clear(); _search(state); })
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                  ),
                )),
                const SizedBox(width: 8),
                _ToolbarBtn(icon: Icons.filter_list_rounded, label: S.filter,
                    active: !_filter.isEmpty,
                    color: _filter.isEmpty ? AppColors.accentBlue : AppColors.warningOrange,
                    onTap: _openFilter),
                const SizedBox(width: 8),
                // Add button — SRS §3.3.1
                _ToolbarBtn(
                  icon: Icons.person_add_rounded,
                  label: S.add,
                  color: AppColors.successGreen,
                  onTap: () => _openAdd(state),
                ),
                const SizedBox(width: 8),
                _ToolbarBtn(icon: Icons.upload_rounded, label: S.importExcel, onTap: () async {
                  final ok = await state.importFromExcel();
                  if (!context.mounted) return;
                  if (ok) {
                    showSuccess(context, S.importSuccess);
                  } else {
                    showError(context, S.importFailed);
                  }
                }),
                const SizedBox(width: 8),
                _ToolbarBtn(icon: Icons.download_rounded, label: S.exportExcel, onTap: () async {
                  final ok = await state.exportToExcel();
                  if (!context.mounted) return;
                  if (ok) {
                    showSuccess(context, S.exportSuccess);
                  } else {
                    showError(context, S.exportFailed);
                  }
                }),
                // Refresh from Cloud — only relevant once signed in to
                // Firebase; this is the explicit full-roster pull, deliberately
                // kept separate from the Print screen's single-patient Sync
                // HIS button (which stays cheap on every click).
                if (state.isCloudSignedIn) ...[
                  const SizedBox(width: 8),
                  _ToolbarBtn(
                    icon: Icons.cloud_sync_rounded,
                    label: S.refreshFromCloud,
                    active: state.isCloudSyncing,
                    color: AppColors.primaryBlue,
                    onTap: state.isCloudSyncing ? () {} : () async {
                      await state.syncWithFirebase();
                      if (!context.mounted) return;
                      if (state.cloudSyncError != null) {
                        showError(context, state.cloudSyncError!);
                      } else {
                        showSuccess(context, S.saveSuccess);
                      }
                    },
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            // ── Patient cards ───────────────────────────────────────────────
            // Big text, big tappable buttons, one patient per card — easier to
            // read and tap at a glance than a dense multi-column table row.
            Expanded(
              child: state.isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                  : patients.isEmpty
                      ? _EmptyState(message: state.searchQuery.isEmpty ? S.noPatients : 'No results for "${state.searchQuery}"')
                      : ListView.separated(
                          itemCount: patients.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) => _PatientCard(
                            patient: patients[i],
                            onDelete: () => _confirmDelete(state, patients[i]),
                            onEdit:   () => _openEdit(state, patients[i]),
                            onPrint:  () async {
                              final ok = await state.printWristband(patients[i]);
                              if (!context.mounted) return;
                              if (ok) {
                                showSuccess(context, S.printSuccess);
                              } else {
                                showError(context, S.printFailed);
                              }
                            },
                          ),
                        ),
            ),
            // ── Pagination ──────────────────────────────────────────────────
            GlassBox(
              blur: 15, opacity: 0.07,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Text('${S.loadedOf} ${patients.length} ${S.of} ${state.totalPatientCount}',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                _PageBtn(icon: Icons.chevron_left_rounded, label: S.prevPage,
                    enabled: state.patientPage > 0, onTap: () => state.prevPatientPage()),
                const SizedBox(width: 10),
                GlassPill(text: '${S.page} ${state.patientPage + 1}', color: AppColors.primaryBlue),
                const SizedBox(width: 10),
                _PageBtn(icon: Icons.chevron_right_rounded, label: S.nextPage,
                    enabled: state.hasMorePatients, onTap: () => state.nextPatientPage()),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color color;

  _ToolbarBtn({
    required this.icon, required this.label, required this.onTap,
    this.active = false, Color? color,
  }) : color = color ?? AppColors.accentBlue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : AppColors.glassBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? color.withValues(alpha: 0.4) : AppColors.glassBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? color : AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: active ? color : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _PatientCard extends StatefulWidget {
  final Patient patient;
  final VoidCallback onDelete, onEdit, onPrint;

  const _PatientCard({
    required this.patient,
    required this.onDelete, required this.onEdit, required this.onPrint,
  });

  @override
  State<_PatientCard> createState() => _PatientCardState();
}

class _PatientCardState extends State<_PatientCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final hasAllergy = p.allergy.isNotEmpty && p.allergy.toLowerCase() != 'none';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GlassBox(
        blur: 15,
        opacity: _hovered ? 0.12 : 0.07,
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Name ──────────────────────────────────────────────────────
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
              ),
              child: Center(child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(color: AppColors.accentBlue, fontSize: 18, fontWeight: FontWeight.w700),
              )),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(p.name,
                style: TextStyle(fontSize: 21, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 10),
            _GenderBadge(gender: p.gender),
          ]),
          const SizedBox(height: 16),
          // ── Fields ────────────────────────────────────────────────────
          Wrap(spacing: 28, runSpacing: 12, children: [
            _Field(label: S.patientId, value: p.patientId),
            _Field(label: S.bloodType, value: p.bloodType, valueColor: AppColors.bloodType, bold: true),
            _Field(label: S.department, value: p.department),
            _Field(label: S.doctor, value: p.doctor),
            _Field(label: S.dateOfBirth, value: p.dateOfBirth),
            _Field(label: S.admissionTimeShort, value: p.admissionTime),
            _Field(
              label: S.allergy,
              value: p.allergy.isEmpty ? '—' : p.allergy,
              valueColor: hasAllergy ? AppColors.allergyColor : null,
              bold: hasAllergy,
            ),
          ]),
          const SizedBox(height: 16),
          // ── Actions ───────────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _CardActionBtn(icon: Icons.edit_rounded,   label: S.edit,     color: AppColors.accentBlue,   onTap: widget.onEdit),
            const SizedBox(width: 10),
            _CardActionBtn(icon: Icons.print_rounded,  label: S.printBtn, color: AppColors.successGreen, onTap: widget.onPrint),
            const SizedBox(width: 10),
            _CardActionBtn(icon: Icons.delete_rounded, label: S.delete,   color: AppColors.errorRed,     onTap: widget.onDelete),
          ]),
        ]),
      ),
    );
  }
}

/// A single labeled value in a patient card, e.g. "PATIENT ID" / "A00033".
class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _Field({required this.label, required this.value, this.valueColor, this.bold = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w600,
        color: AppColors.textMuted, letterSpacing: 0.5,
      )),
      const SizedBox(height: 3),
      Text(value.isEmpty ? '—' : value, style: TextStyle(
        fontSize: 15,
        color: valueColor ?? AppColors.textPrimary,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
      )),
    ],
  );
}

class _GenderBadge extends StatelessWidget {
  final String gender;
  const _GenderBadge({required this.gender});

  @override
  Widget build(BuildContext context) {
    final isMale = gender == 'Male';
    final color = isMale ? AppColors.primaryBlue : const Color(0xFFEC4899);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(isMale ? Icons.male_rounded : Icons.female_rounded, size: 18, color: color),
        const SizedBox(width: 4),
        Text(isMale ? S.male : S.female, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Big, clearly-labeled action button — replaces the old icon-only 28x28
/// tap target so the button is easy to hit and its purpose is unambiguous
/// on a touch panel.
class _CardActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _CardActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _PageBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _PageBtn({required this.icon, required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.accentBlue : AppColors.textMuted;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ]),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline_rounded, size: 40, color: AppColors.textMuted.withValues(alpha: 0.4)),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
    ]));
  }
}
