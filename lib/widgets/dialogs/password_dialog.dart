import 'package:flutter/material.dart';
import '../../core/strings.dart';
import '../../core/app_theme.dart';
import '../../services/settings_service.dart';
import 'base_dialog.dart';

class PasswordDialog extends StatefulWidget {
  const PasswordDialog({super.key});
  @override
  State<PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<PasswordDialog> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureOld = true, _obscureNew = true, _obscureConfirm = true;
  String? _error;
  final _settings = SettingsService.instance;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _save() {
    setState(() => _error = null);
    if (_settings.hasPassword) {
      if (!_settings.verifyPassword(_oldCtrl.text)) {
        setState(() => _error = S.wrongPassword);
        return;
      }
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = S.passwordMismatch);
      return;
    }
    if (_newCtrl.text.isEmpty) {
      setState(() => _error = S.fieldRequired);
      return;
    }
    _settings.setPassword(_newCtrl.text);
    Navigator.pop(context);
    showSuccess(context, S.passwordSaved);
  }

  @override
  Widget build(BuildContext context) {
    final hasPass = _settings.hasPassword;
    return BaseDialog(
      title: S.passwordConfig,
      icon: Icons.lock_rounded,
      width: 400,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_rounded, size: 16, color: AppColors.errorRed),
                  const SizedBox(width: 8),
                  Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 13)),
                ],
              ),
            ),
          if (hasPass) ...[
            _PassField(label: S.oldPassword, ctrl: _oldCtrl, obscure: _obscureOld, toggle: () => setState(() => _obscureOld = !_obscureOld)),
            const SizedBox(height: 12),
          ],
          _PassField(label: S.newPassword, ctrl: _newCtrl, obscure: _obscureNew, toggle: () => setState(() => _obscureNew = !_obscureNew)),
          const SizedBox(height: 12),
          _PassField(label: S.confirmPassword, ctrl: _confirmCtrl, obscure: _obscureConfirm, toggle: () => setState(() => _obscureConfirm = !_obscureConfirm)),
        ],
      ),
      actions: [
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
        ElevatedButton(onPressed: _save, child: Text(S.save)),
      ],
    );
  }
}

class _PassField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool obscure;
  final VoidCallback toggle;

  const _PassField({required this.label, required this.ctrl, required this.obscure, required this.toggle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 18),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}
