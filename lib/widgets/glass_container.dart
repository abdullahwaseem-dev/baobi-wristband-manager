import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class GlassBox extends StatelessWidget {
  final Widget child;
  final double blur;
  final Color tint;
  final double opacity;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final List<BoxShadow>? shadows;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  const GlassBox({
    super.key,
    required this.child,
    this.blur = 30,
    this.tint = Colors.white,
    this.opacity = 0.08,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1.0,
    this.padding,
    this.margin,
    this.shadows,
    this.width,
    this.height,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;
    final br = borderRadius ?? BorderRadius.circular(16);

    // Light mode: seashell/mint canvas. Use white glass at higher opacity so
    // panels are clearly visible and crisp against the light background.
    final Color glassTint;
    final double glassOpacity;
    if (!isDark && tint == Colors.white && opacity < 0.5) {
      glassTint   = Colors.white;
      glassOpacity = 0.62;
    } else {
      glassTint   = tint;
      glassOpacity = opacity;
    }

    final bc = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFF00A878).withValues(alpha: 0.22));

    final effectiveShadows = shadows ??
        (isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.04),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ]
            : [
                // Subtle drop shadow for white cards on seashell bg
                BoxShadow(
                  color: const Color(0x1800A878),
                  blurRadius: 24,
                  spreadRadius: -2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]);

    final container = ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: glassTint.withValues(alpha: glassOpacity),
            borderRadius: br,
            border: Border.all(color: bc, width: borderWidth),
            boxShadow: effectiveShadows,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(margin: margin, child: container),
      );
    }
    return Container(margin: margin, child: container);
  }
}

/// Ambient gradient orb for background depth
class GlassOrb extends StatelessWidget {
  final double size;
  final Color color;

  const GlassOrb({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          radius: 0.7,
        ),
      ),
    );
  }
}

/// Convenience pill-shaped glass badge
class GlassPill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const GlassPill({super.key, required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
              ],
              Text(text,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
