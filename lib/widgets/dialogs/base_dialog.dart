import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class BaseDialog extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget content;
  final List<Widget> actions;
  final double width;

  const BaseDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.content,
    required this.actions,
    this.width = 480,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: AppColors.glassBgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorderStrong, width: 1.0),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 60, offset: const Offset(0, 20)),
                BoxShadow(color: AppColors.primaryBlue.withValues(alpha: 0.08), blurRadius: 40),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.35)),
                        ),
                        child: Icon(icon, size: 17, color: AppColors.accentBlue),
                      ),
                      const SizedBox(width: 12),
                      Text(title, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2)),
                      const Spacer(),
                      _CloseBtn(onTap: () => Navigator.pop(context)),
                    ],
                  ),
                ),
                // ── Body ───────────────────────────────────────────────────
                Padding(padding: const EdgeInsets.all(20), child: content),
                // ── Footer ─────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions
                        .expand((w) => [w, const SizedBox(width: 8)])
                        .toList()
                      ..removeLast(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _CloseBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── Snackbar helpers ─────────────────────────────────────────────────────────

void showSuccess(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: Colors.white, fontSize: 13))),
    ]),
    backgroundColor: AppColors.successGreen,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 2),
    margin: const EdgeInsets.all(16),
  ));
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(Icons.error_rounded, color: Colors.white, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: Colors.white, fontSize: 13))),
    ]),
    backgroundColor: AppColors.errorRed,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    duration: const Duration(seconds: 3),
    margin: const EdgeInsets.all(16),
  ));
}
