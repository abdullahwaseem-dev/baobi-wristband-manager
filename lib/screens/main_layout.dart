import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/app_state.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/app_bottom_bar.dart';
import '../widgets/glass_container.dart';
import 'home_screen.dart';
import 'print_screen.dart';
import 'patient_list_screen.dart';
import 'print_queue_screen.dart';

class MainLayout extends StatelessWidget {
  const MainLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Scaffold(
          backgroundColor: AppColors.bg1,
          body: Stack(
            children: [
              // ── Gradient background canvas ───────────────────────────────
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.bg1, AppColors.bg2, AppColors.bg3],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
              // ── Ambient light orbs ───────────────────────────────────────
              Positioned(top: -160, left: -100,
                  child: GlassOrb(size: 520, color: AppColors.orb1)),
              Positioned(bottom: -140, right: -80,
                  child: GlassOrb(size: 440, color: AppColors.orb2)),
              Positioned(top: 160, right: 60,
                  child: GlassOrb(size: 260, color: AppColors.orb3)),
              Positioned(top: 300, left: 80,
                  child: GlassOrb(size: 180, color: AppColors.isDark ? const Color(0x1A7C3AED) : const Color(0x0F7C3AED))),
              // ── UI Shell ─────────────────────────────────────────────────
              Column(
                children: [
                  const AppTopBar(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const AppSidebar(),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
                              child: child,
                            ),
                            child: switch (state.page) {
                              AppPage.home => const HomeScreen(key: ValueKey('home')),
                              AppPage.print => const PrintScreen(key: ValueKey('print')),
                              AppPage.patientList => const PatientListScreen(key: ValueKey('patients')),
                              AppPage.printQueue => const PrintQueueScreen(key: ValueKey('queue')),
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const AppBottomBar(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
