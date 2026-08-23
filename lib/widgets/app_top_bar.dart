import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../state/app_state.dart';

class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key});

  String _pageTitle(AppPage page) => switch (page) {
        AppPage.home       => S.navHome,
        AppPage.print      => S.manualPrint,
        AppPage.patientList=> S.patientListTitle,
        AppPage.printQueue => S.printQueueTitle,
      };

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                border: Border(
                  bottom: BorderSide(color: AppColors.glassBorder),
                ),
              ),
              child: Row(
                children: [
                  // ── Logo zone ────────────────────────────────────────────
                  SizedBox(
                    width: 90,
                    child: Center(
                      child: Image.asset(
                        'assets/images/baobi_logo.png',
                        height: 22,
                        fit: BoxFit.contain,
                        color: AppColors.isDark ? null : const Color(0xFF1E3A8A),
                        colorBlendMode: AppColors.isDark ? null : BlendMode.modulate,
                      ),
                    ),
                  ),
                  // ── Divider ──────────────────────────────────────────────
                  Container(width: 1, height: 24, color: AppColors.glassBorder),
                  const SizedBox(width: 16),
                  // ── Subtitle ─────────────────────────────────────────────
                  Text(
                    'Medical Wristband System',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // ── Page title (center) ──────────────────────────────────
                  Expanded(
                    child: Center(
                      child: Text(
                        _pageTitle(state.page),
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  // ── Theme toggle ─────────────────────────────────────────
                  _ThemeToggle(isDark: state.isDarkMode, onToggle: state.setDarkMode),
                  const SizedBox(width: 8),
                  // ── Language switcher (EN | AR | 中) ─────────────────────
                  _LangSwitcher(current: state.language, onChanged: state.setLanguage),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Theme Toggle ─────────────────────────────────────────────────────────────

class _ThemeToggle extends StatelessWidget {
  final bool isDark;
  final ValueChanged<bool> onToggle;
  const _ThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onToggle(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primaryBlue.withValues(alpha: 0.15)
              : AppColors.warningOrange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? AppColors.primaryBlue.withValues(alpha: 0.4)
                : AppColors.warningOrange.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              size: 14,
              color: isDark ? AppColors.accentBlue : AppColors.warningOrange,
            ),
            const SizedBox(width: 5),
            Text(
              isDark ? S.darkMode : S.lightMode,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.accentBlue : AppColors.warningOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Language Switcher ────────────────────────────────────────────────────────

class _LangSwitcher extends StatelessWidget {
  final String current;
  final ValueChanged<String> onChanged;
  const _LangSwitcher({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LangBtn(label: 'EN', active: current == 'en', onTap: () => onChanged('en'), isDark: AppColors.isDark),
              _LangBtn(label: 'AR', active: current == 'ar', onTap: () => onChanged('ar'), isDark: AppColors.isDark),
              _LangBtn(label: '中', active: current == 'zh', onTap: () => onChanged('zh'), isDark: AppColors.isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangBtn extends StatelessWidget {
  final String label;
  final bool active;
  final bool isDark;
  final VoidCallback onTap;
  const _LangBtn({required this.label, required this.active, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (isDark ? Colors.white : AppColors.primaryBlue)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: active
              ? [BoxShadow(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primaryBlue.withValues(alpha: 0.3),
                  blurRadius: 8)]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? (isDark ? AppColors.bg2 : Colors.white)
                : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
