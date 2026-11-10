import 'package:flutter/widgets.dart';

import '../../app.dart';

/// Shared press feedback: shrinks slightly while pressed and springs back
/// with a small overshoot on release. Doesn't consume taps (uses a
/// [Listener]), so it can wrap any button. Respects "reduce motion".
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true, this.depth = 0.05});

  final Widget child;
  final bool enabled;

  /// Scale reduction while pressed (0.05 → 95 %).
  final double depth;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, lowerBound: -1, upperBound: 1, value: 0);

  bool get _reduced {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    return scope?.notifier?.reduceMotion ?? false;
  }

  void _down(PointerDownEvent _) {
    if (!widget.enabled || _reduced) return;
    _c.animateTo(1, duration: const Duration(milliseconds: 80), curve: Curves.easeOut);
  }

  void _up(PointerEvent _) {
    if (_c.value == 0) return;
    // Spring back: elasticOut overshoots past 0 → scale slightly above 1.
    _c.animateTo(0, duration: const Duration(milliseconds: 420), curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(scale: 1 - widget.depth * _c.value, child: child),
        child: widget.child,
      ),
    );
  }
}
