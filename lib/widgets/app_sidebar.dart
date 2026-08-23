import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../state/app_state.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                border: Border(right: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // ── Logo ────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.glassBorderStrong.withValues(alpha: 0.5)),
                        ),
                        child: Image.asset(
                          'assets/images/baobi_logo.png',
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MEDICAL',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Divider(color: AppColors.glassBorder, indent: 14, endIndent: 14, thickness: 0.5),
                  const SizedBox(height: 10),
                  // ── Navigation items ────────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        _NavItem(icon: Icons.home_rounded,    label: S.navHome,        page: AppPage.home,        current: state.page, onTap: () => state.navigate(AppPage.home)),
                        _NavItem(icon: Icons.print_rounded,   label: S.navPrint,       page: AppPage.print,       current: state.page, onTap: () => state.navigate(AppPage.print)),
                        _NavItem(icon: Icons.people_rounded,  label: S.navPatientList, page: AppPage.patientList, current: state.page, onTap: () => state.navigate(AppPage.patientList)),
                        _NavItem(icon: Icons.queue_rounded,   label: S.navPrintQueue,  page: AppPage.printQueue,  current: state.page, onTap: () => state.navigate(AppPage.printQueue)),
                      ],
                    ),
                  ),
                  // ── Print count badge ────────────────────────────────────
                  if (state.pendingPrintCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _GlowBadge(count: state.pendingPrintCount),
                    ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPage page, current;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.page, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = page == current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          hoverColor: Colors.white.withValues(alpha: 0.08),
          splashColor: isActive ? AppColors.navActiveGlow : AppColors.primaryGlow,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isActive ? AppColors.navActive.withValues(alpha: 0.18) : Colors.transparent,
              border: isActive
                  ? Border.all(color: AppColors.navActive.withValues(alpha: 0.4), width: 1)
                  : Border.all(color: Colors.transparent),
              boxShadow: isActive
                  ? [BoxShadow(color: AppColors.navActiveGlow, blurRadius: 16, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: isActive
                      ? BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.navActive, AppColors.navActive.withValues(alpha: 0.75)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: AppColors.navActiveGlow, blurRadius: 14, spreadRadius: 1),
                          ],
                        )
                      : null,
                  child: Icon(icon, size: 20,
                      color: isActive ? Colors.white : AppColors.navInactive),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppColors.textPrimary : AppColors.navInactive,
                    fontSize: 9.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowBadge extends StatelessWidget {
  final int count;
  const _GlowBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.navActive.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navActive.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppColors.navActiveGlow, blurRadius: 10)],
      ),
      child: Text('$count', style: TextStyle(color: AppColors.navActive, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
