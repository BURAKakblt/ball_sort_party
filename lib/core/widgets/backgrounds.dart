import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Soft gradient with blurred color blobs for depth.
class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Stack(
        children: [
          const _Blob(alignment: Alignment(-1.3, -0.9), color: AppColors.violet, size: 1.1),
          const _Blob(alignment: Alignment(1.4, -0.2), color: AppColors.turquoise, size: 0.9),
          const _Blob(alignment: Alignment(-0.8, 1.2), color: Color(0xFF3B6BFF), size: 1.0),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.alignment, required this.color, required this.size});

  final Alignment alignment;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: alignment,
              radius: size,
              colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Translucent rounded panel with a light border.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.highlight,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Optional accent used for a glowing border.
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: (highlight ?? Colors.white).withValues(alpha: highlight != null ? 0.8 : 0.22),
          width: 1.5,
        ),
        boxShadow: [
          if (highlight != null)
            BoxShadow(color: highlight!.withValues(alpha: 0.35), blurRadius: 18),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
