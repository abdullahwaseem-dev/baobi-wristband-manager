import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_theme.dart';
import '../../core/strings.dart';
import '../../services/firebase_auth_service.dart';
import '../../state/app_state.dart';
import 'base_dialog.dart';

/// Sign in/out for cloud sync (Firebase). One account per hospital, issued
/// by the vendor — entered once here, remembered thereafter. Mirrors
/// his_dialog.dart's visual style; much simpler since there's no multi-tab
/// config, just credentials + status.
class FirebaseLoginDialog extends StatefulWidget {
  const FirebaseLoginDialog({super.key});
  @override
  State<FirebaseLoginDialog> createState() => _FirebaseLoginDialogState();
}

class _FirebaseLoginDialogState extends State<FirebaseLoginDialog> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _isSignedIn => FirebaseAuthService.instance.isSignedIn;

  Future<void> _signIn() async {
    setState(() { _busy = true; _error = null; });
    final r = await FirebaseAuthService.instance.signIn(_emailCtrl.text, _passwordCtrl.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      showSuccess(context, S.cloudSignInSuccess);
      // Immediately pull the shared roster so Patient List fills in without
      // a separate manual step — same pattern as the HIS dialog's Save.
      final appState = context.read<AppState>();
      setState(() => _busy = true);
      await appState.syncWithFirebase();
      if (!mounted) return;
      setState(() => _busy = false);
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = r.error);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuthService.instance.signOut();
    if (!mounted) return;
    setState(() {});
    showSuccess(context, S.cloudSignedOut);
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    final appState = context.read<AppState>();
    await appState.syncWithFirebase();
    if (!mounted) return;
    setState(() => _busy = false);
    if (appState.cloudSyncError != null) {
      showError(context, appState.cloudSyncError!);
    } else {
      showSuccess(context, S.saveSuccess);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseDialog(
      title: S.cloudSignInTitle,
      icon: Icons.cloud_rounded,
      width: 440,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.cloudSignInSubtitle, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 16),
          if (_isSignedIn) ..._signedInContent() else ..._signInForm(),
        ],
      ),
      actions: _isSignedIn
          ? [
              OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(S.close)),
              OutlinedButton(onPressed: _busy ? null : _signOut, child: Text(S.cloudSignOut)),
              ElevatedButton.icon(
                onPressed: _busy ? null : _syncNow,
                icon: _busy
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(S.cloudSyncNow),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              ),
            ]
          : [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(S.cancel)),
              ElevatedButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login_rounded, size: 16),
                label: Text(S.cloudSignIn),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
              ),
            ],
    );
  }

  List<Widget> _signInForm() => [
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.warning_rounded, size: 16, color: AppColors.errorRed),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: TextStyle(color: AppColors.errorRed, fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 12),
        ],
        Text(S.cloudEmail, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: const InputDecoration(hintText: 'hospital@example.com', prefixIcon: Icon(Icons.mail_outline_rounded, size: 16)),
        ),
        const SizedBox(height: 12),
        Text(S.password, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscure,
          onSubmitted: (_) => _signIn(),
          style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 16),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 16),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
      ];

  List<Widget> _signedInContent() => [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.successGreen.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(Icons.cloud_done_rounded, color: AppColors.successGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(S.cloudSignedInAs, style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                Text(FirebaseAuthService.instance.signedInEmail,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Consumer<AppState>(
          builder: (context, state, _) {
            final last = state.lastCloudSyncAt;
            return Row(children: [
              Icon(Icons.history_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${S.cloudLastSynced}: ${last == null ? S.cloudNeverSynced : _fmt(last)}',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ]);
          },
        ),
      ];

  String _fmt(DateTime t) =>
      '${t.year}.${t.month.toString().padLeft(2, '0')}.${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

Future<bool> showFirebaseLoginDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => const FirebaseLoginDialog(),
  );
  return result ?? false;
}
