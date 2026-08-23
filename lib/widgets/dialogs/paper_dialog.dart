import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../models/paper_config.dart';
import '../../state/app_state.dart';
import 'base_dialog.dart';

/// Paper size + printer name configuration dialog.
/// Lists all 35 BB720A paper configurations (see PaperConfig for provenance).
class PaperDialog extends StatefulWidget {
  final String currentItemNo;
  final String currentPrinterName;
  final int currentChannel;

  const PaperDialog({
    super.key,
    required this.currentItemNo,
    required this.currentPrinterName,
    required this.currentChannel,
  });

  @override
  State<PaperDialog> createState() => _PaperDialogState();
}

class _PaperDialogState extends State<PaperDialog> {
  late String _selected;
  late int    _channel;
  late final _printerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.currentItemNo;
    _channel  = widget.currentChannel;
    _printerCtrl.text = widget.currentPrinterName;
  }

  @override
  void dispose() {
    _printerCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final state = context.read<AppState>();
    state.setPaperConfig(_selected);
    state.setPrinterName(_printerCtrl.text.trim());
    state.setPrintChannel(_channel);
    Navigator.pop(context);
    showSuccess(context, S.paperSaved);
  }

  @override
  Widget build(BuildContext context) {
    final current = PaperConfig.byItemNo(_selected);
    return BaseDialog(
      title: S.paperSize,
      icon: Icons.straighten_rounded,
      width: 560,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Paper list ───────────────────────────────────────────────────
          _label(S.selectPaper),
          const SizedBox(height: 6),
          // Which document each stock's dimensions came from. The dot used to
          // repeat the B/F/– suffix, which is already the last character of the
          // item number right beside it — colouring by source instead tells
          // staff which sheet to check their physical box against.
          // Wrap, not Row: the Arabic labels are long enough that a fixed row
          // would overflow the 560px dialog.
          Wrap(spacing: 14, runSpacing: 4, children: [
            _LegendDot(color: AppColors.primaryBlue,  label: S.paperFromReference),
            _LegendDot(color: AppColors.accentViolet, label: S.paperFromSpecSheet),
          ]),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(children: PaperConfig.all.map((p) {
                final sel = _selected == p.itemNo;
                final sheet = p.isFromSpecSheet;
                final accent = sheet ? AppColors.accentViolet : AppColors.primaryBlue;
                return GestureDetector(
                  onTap: () => setState(() => _selected = p.itemNo),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? accent.withValues(alpha: 0.15) : AppColors.glassBgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? accent : AppColors.glassBorder,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Row(children: [
                      // Colour indicator by source document (see legend above)
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Row(children: [
                          Flexible(
                            child: Text(p.itemNo,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                                  color: sel ? accent : AppColors.textPrimary,
                                )),
                          ),
                          // Redundant with the dot colour on purpose — the mark
                          // has to survive a colour-blind user and a mono print.
                          if (sheet) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.accentViolet.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.45)),
                              ),
                              child: Text('PDF',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                    color: AppColors.accentViolet,
                                  )),
                            ),
                          ],
                        ]),
                      ),
                      const SizedBox(width: 10),
                      Text('${p.faceMm.toStringAsFixed(0)}×${p.widthMm.toStringAsFixed(0)} mm',
                          style: TextStyle(fontSize: 11, color: sel ? accent : AppColors.textMuted)),
                      const SizedBox(width: 12),
                      Text('strip ${p.stripMm.toStringAsFixed(0)} mm',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      const SizedBox(width: 10),
                      _BlackBarTag(mm: p.blackBarMm),
                      if (sel) ...[const SizedBox(width: 8), Icon(Icons.check_circle_rounded, size: 16, color: accent)],
                    ]),
                  ),
                );
              }).toList()),
            ),
          ),
          const SizedBox(height: 14),
          // ── Selected info ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.25)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${current.itemNo}  ·  Face ${_mm(current.faceMm)}×${_mm(current.widthMm)} mm  ·  Strip ${_mm(current.stripMm)} mm',
                  style: TextStyle(fontSize: 11, color: AppColors.accentBlue),
                ),
                const SizedBox(height: 3),
                Text(
                  '${S.blackBar} ${_mm(current.blackBarMm)} mm ${S.fromLeadEdge} — ${S.printStartsAfterBar}'
                  // Only worth the line noise on the stocks that actually
                  // carry a trim; it's 0 on everything else.
                  '${current.printOffsetMm == 0 ? '' : '  ·  ${S.printOffset} +${_mm(current.printOffsetMm)} mm'}',
                  style: TextStyle(fontSize: 11, color: AppColors.accentBlue),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 14),
          // ── Windows printer name ──────────────────────────────────────────
          _label(S.printerName),
          const SizedBox(height: 6),
          TextField(
            controller: _printerCtrl,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'BaobiPrinter BB720A',
              prefixIcon: Icon(Icons.print_rounded, size: 15),
              helperText: S.printerNameHelper,
              helperStyle: TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 14),
          // ── Print channel ─────────────────────────────────────────────────
          _label(S.printChannel),
          const SizedBox(height: 8),
          Row(children: [
            _ChannelBtn(label: '0 — ${S.channelUpper}', value: 0, selected: _channel, onSelect: (v) => setState(() => _channel = v)),
            const SizedBox(width: 8),
            _ChannelBtn(label: '1 — ${S.channelLower}', value: 1, selected: _channel, onSelect: (v) => setState(() => _channel = v)),
            const SizedBox(width: 8),
            _ChannelBtn(label: '2 — ${S.channelDefault}', value: 2, selected: _channel, onSelect: (v) => setState(() => _channel = v)),
          ]),
        ],
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

  Widget _label(String text) => Text(text,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary));
}

/// Drop the trailing `.0` on whole millimetre values — most of these are whole
/// numbers and "285.0×36.0 mm" reads badly next to a spec sheet saying "285 mm".
String _mm(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(1);

/// One swatch in the source legend above the paper list.
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
    const SizedBox(width: 5),
    Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]);
}

/// Miniature of the black registration bar printed on the band, with how far in
/// from the leading edge it sits. The BB720A's sensor stops the media on this
/// bar, so it's where printing begins — the number staff need when they're
/// checking alignment against the spec sheet.
class _BlackBarTag extends StatelessWidget {
  final double mm;
  const _BlackBarTag({required this.mm});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 3, height: 11,
      // textPrimary, not literal black: near-black on the light theme and
      // near-white on the dark one, so the marker stays visible either way.
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(1),
      ),
    ),
    const SizedBox(width: 4),
    Text('${_mm(mm)} mm', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
  ]);
}

class _ChannelBtn extends StatelessWidget {
  final String label;
  final int value, selected;
  final ValueChanged<int> onSelect;
  const _ChannelBtn({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final sel = value == selected;
    final color = sel ? AppColors.accentBlue : AppColors.textMuted;
    return Expanded(child: GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: sel ? AppColors.primaryBlue.withValues(alpha: 0.15) : AppColors.glassBgInput,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? AppColors.primaryBlue : AppColors.glassBorder, width: sel ? 1.5 : 1),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: sel ? FontWeight.w600 : FontWeight.w400))),
      ),
    ));
  }
}

