import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/strings.dart';
import '../../core/app_theme.dart';
import '../../state/app_state.dart';
import 'base_dialog.dart';

class SpeedDialog extends StatefulWidget {
  final int current;
  const SpeedDialog({super.key, required this.current});
  @override
  State<SpeedDialog> createState() => _SpeedDialogState();
}

class _SpeedDialogState extends State<SpeedDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.speedConfig,
      icon: Icons.speed_rounded,
      width: 380,
      content: _GearSelector(
        selected: _selected,
        label: S.printSpeed,
        onChanged: (v) => setState(() => _selected = v),
        icon: Icons.speed_rounded,
        color: AppColors.primaryBlue,
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
        ElevatedButton(
          onPressed: () {
            context.read<AppState>().setPrintSpeed(_selected);
            Navigator.pop(context);
            showSuccess(context, '${S.printSpeed}: ${S.gear} $_selected');
          },
          child: Text(S.ok),
        ),
      ],
    );
  }
}

class DensityDialog extends StatefulWidget {
  final int current;
  const DensityDialog({super.key, required this.current});
  @override
  State<DensityDialog> createState() => _DensityDialogState();
}

class _DensityDialogState extends State<DensityDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.densityConfig,
      icon: Icons.contrast_rounded,
      width: 380,
      content: _GearSelector(
        selected: _selected,
        label: S.printDensity,
        onChanged: (v) => setState(() => _selected = v),
        icon: Icons.contrast_rounded,
        color: AppColors.accentBlue,
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
        ElevatedButton(
          onPressed: () {
            context.read<AppState>().setPrintDensity(_selected);
            Navigator.pop(context);
            showSuccess(context, '${S.printDensity}: ${S.gear} $_selected');
          },
          child: Text(S.ok),
        ),
      ],
    );
  }
}

class _GearSelector extends StatelessWidget {
  final int selected;
  final String label;
  final ValueChanged<int> onChanged;
  final IconData icon;
  final Color color;

  const _GearSelector({
    required this.selected,
    required this.label,
    required this.onChanged,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(S.selectGear, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(10, (i) {
            final gear = i + 6;
            final isSelected = gear == selected;
            return GestureDetector(
              onTap: () => onChanged(gear),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isSelected ? color : AppColors.contentBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? color : AppColors.borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$gear',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      S.gear,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? Colors.white.withValues(alpha: 0.8) : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Text(
                '${S.currentGear}: ${S.gear} $selected',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
              ),
              const Spacer(),
              Text(
                selected == 14 ? '(Default)' : selected > 14 ? '(Faster)' : '(Slower)',
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
