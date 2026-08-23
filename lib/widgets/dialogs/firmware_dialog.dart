import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/app_theme.dart';
import '../../services/settings_service.dart';
import 'base_dialog.dart';

class FirmwareDialog extends StatefulWidget {
  const FirmwareDialog({super.key});
  @override
  State<FirmwareDialog> createState() => _FirmwareDialogState();
}

class _FirmwareDialogState extends State<FirmwareDialog> {
  bool _checking = false;
  String? _updateMsg;

  Future<void> _check() async {
    setState(() { _checking = true; _updateMsg = null; });
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() { _checking = false; _updateMsg = S.upToDate; });
  }

  @override
  Widget build(BuildContext context) {
    final version = SettingsService.instance.firmwareVersion;
    return BaseDialog(
      title: S.firmwareInfo,
      icon: Icons.memory_rounded,
      width: 360,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Icon(Icons.memory_rounded, size: 40, color: AppColors.primaryBlue),
                const SizedBox(height: 12),
                Text(S.currentVersion, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(version, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.primaryBlue, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text('BB720A Medical Wristband Terminal', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (_updateMsg != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successGreen),
                  const SizedBox(width: 8),
                  Text(_updateMsg!, style: TextStyle(color: AppColors.successGreen, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.close)),
        ElevatedButton.icon(
          onPressed: _checking ? null : _check,
          icon: _checking
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.system_update_rounded, size: 16),
          label: Text(S.checkUpdate),
        ),
      ],
    );
  }
}
