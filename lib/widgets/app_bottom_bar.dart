import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../state/app_state.dart';

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: Color(0x1A000000),
                border: Border(top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 96),
                  // Ready to Print
                  _StatusChip(
                    icon: state.readyToPrint ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    label: S.readyToPrint,
                    color: state.readyToPrint ? AppColors.successGreen : AppColors.warningOrange,
                  ),
                  const SizedBox(width: 6),
                  Container(width: 1, height: 14, color: AppColors.glassBorder),
                  const SizedBox(width: 12),
                  // Print Count
                  _StatusChip(
                    icon: Icons.print_rounded,
                    label: '${S.printCount}: ${state.pendingPrintCount}',
                    color: AppColors.accentBlue,
                  ),
                  const Spacer(),
                  // Manufacturer
                  Text(
                    S.manufacturer,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 10,
                      letterSpacing: 0.3,
                    ),
                  ),
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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
