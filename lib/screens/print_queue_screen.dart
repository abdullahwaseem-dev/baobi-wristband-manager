import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/print_record.dart';
import '../state/app_state.dart';
import '../widgets/glass_container.dart';
import '../widgets/dialogs/base_dialog.dart';
import '../widgets/dialogs/filter_dialog.dart';

class PrintQueueScreen extends StatefulWidget {
  const PrintQueueScreen({super.key});
  @override
  State<PrintQueueScreen> createState() => _PrintQueueScreenState();
}

class _PrintQueueScreenState extends State<PrintQueueScreen> {
  final _searchCtrl = TextEditingController();
  FilterResult _filter = const FilterResult();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPrintRecords();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _search(AppState state) =>
      state.searchPrintRecords(_searchCtrl.text.trim(), filter: _filter);

  Future<void> _openFilter() async {
    final result = await showDialog<FilterResult>(
      context: context,
      builder: (_) => FilterDialog(
        initial: _filter,
        showBloodType: false,
        showGender: false,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _search(context.read<AppState>());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final records = state.printRecords;
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
                _FilterBtn(active: !_filter.isEmpty, onTap: _openFilter),
              ]),
            ),
            const SizedBox(height: 12),
            // ── Table header ────────────────────────────────────────────────
            GlassBox(
              blur: 15, opacity: 0.12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                _Hdr(label: S.patientName, flex: 3),
                _Hdr(label: S.patientId, flex: 2),
                _Hdr(label: S.bloodType, flex: 2),
                _Hdr(label: S.department, flex: 3),
                _Hdr(label: S.epcCode, flex: 4),
                _Hdr(label: S.printTime, flex: 3),
              ]),
            ),
            // ── Table rows ──────────────────────────────────────────────────
            Expanded(
              child: state.isLoading
                  ? Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
                  : records.isEmpty
                      ? _EmptyState(message: state.printSearchQuery.isEmpty ? S.noPrintRecords : 'No results')
                      : ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (ctx, i) => _RecordRow(
                            record: records[i], index: i,
                            onTap: () => _showDetail(context, records[i]),
                          ),
                        ),
            ),
            // ── Pagination ──────────────────────────────────────────────────
            GlassBox(
              blur: 15, opacity: 0.07,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Text('${S.loadedOf} ${records.length} ${S.of} ${state.totalPrintCount}',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                const Spacer(),
                _PageBtn(icon: Icons.chevron_left_rounded, label: S.prevPage,
                    enabled: state.printPage > 0, onTap: () => state.prevPrintPage()),
                const SizedBox(width: 10),
                GlassPill(text: '${S.page} ${state.printPage + 1}', color: AppColors.successGreen),
                const SizedBox(width: 10),
                _PageBtn(icon: Icons.chevron_right_rounded, label: S.nextPage,
                    enabled: state.hasMorePrints, onTap: () => state.nextPrintPage()),
              ]),
            ),
          ]),
        );
      },
    );
  }

  void _showDetail(BuildContext context, PrintRecord r) {
    showDialog(
      context: context,
      builder: (_) => BaseDialog(
        title: S.patientDetail,
        icon: Icons.receipt_long_rounded,
        width: 480,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailRow(label: S.patientName,  value: r.name),
            _DetailRow(label: S.patientId,    value: r.patientId),
            _DetailRow(label: S.gender,       value: r.gender),
            _DetailRow(label: S.dateOfBirth,  value: r.dateOfBirth),
            _DetailRow(label: S.bloodType,    value: r.bloodType, valueColor: AppColors.bloodType),
            _DetailRow(label: S.allergy,      value: r.allergy,
                valueColor: (r.allergy.isNotEmpty && r.allergy != 'None') ? AppColors.allergyColor : null),
            _DetailRow(label: S.department,   value: r.department),
            _DetailRow(label: S.doctor,       value: r.doctor),
            _DetailRow(label: S.admissionTime,value: r.admissionTime),
            Divider(color: AppColors.glassBorder, height: 20),
            _DetailRow(label: S.epcCode, value: r.epcCode, mono: true),
            _DetailRow(label: S.tidCode, value: r.tidCode, mono: true),
            _DetailRow(label: S.printTime, value: _fmtTime(r.printTime)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(S.close),
          ),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) =>
      '${t.year}.${t.month.toString().padLeft(2,'0')}.${t.day.toString().padLeft(2,'0')} '
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _FilterBtn extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FilterBtn({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.warningOrange : AppColors.accentBlue;
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
          Icon(Icons.filter_list_rounded, size: 14, color: color),
          const SizedBox(width: 5),
          Text(S.filter, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  final String label;
  final int flex;
  const _Hdr({required this.label, required this.flex});

  @override
  Widget build(BuildContext context) => Expanded(
    flex: flex,
    child: Text(label, style: TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600,
      color: AppColors.textMuted, letterSpacing: 0.5,
    )),
  );
}

class _RecordRow extends StatefulWidget {
  final PrintRecord record;
  final int index;
  final VoidCallback onTap;
  const _RecordRow({required this.record, required this.index, required this.onTap});

  @override
  State<_RecordRow> createState() => _RecordRowState();
}

class _RecordRowState extends State<_RecordRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final odd = widget.index.isOdd;
    final time = '${r.printTime.year}.${r.printTime.month.toString().padLeft(2,'0')}.${r.printTime.day.toString().padLeft(2,'0')}';
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withValues(alpha: 0.06)
                : odd ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
            border: Border(bottom: BorderSide(color: AppColors.glassBorder.withValues(alpha: 0.5))),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.25)),
                ),
                child: Center(child: Text(
                  r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                  style: TextStyle(color: AppColors.successGreen, fontSize: 12, fontWeight: FontWeight.w700),
                )),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(r.name,
                  style: TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis)),
            ])),
            Expanded(flex: 2, child: Text(r.patientId,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(r.bloodType,
                style: TextStyle(fontSize: 12, color: AppColors.bloodType, fontWeight: FontWeight.w700))),
            Expanded(flex: 3, child: Text(r.department,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis)),
            Expanded(flex: 4, child: Text(
              r.epcCode.length > 12 ? '${r.epcCode.substring(0, 12)}…' : r.epcCode,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontFamily: 'monospace'),
            )),
            Expanded(flex: 3, child: Row(children: [
              Text(time, style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 14,
                  color: AppColors.textMuted.withValues(alpha: 0.5)),
            ])),
          ]),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  final bool mono;
  const _DetailRow({required this.label, required this.value, this.valueColor, this.mono = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.textMuted))),
        Expanded(child: Text(value.isEmpty ? '—' : value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? AppColors.textPrimary,
              fontWeight: FontWeight.w500,
              fontFamily: mono ? 'monospace' : null,
            ))),
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
      Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textMuted.withValues(alpha: 0.4)),
      const SizedBox(height: 10),
      Text(message, style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
    ]));
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
