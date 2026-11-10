import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../audio/audio_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'pressable.dart';

/// Big, rounded, layered button that sinks into its depth edge when pressed.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.palette = ButtonPalette.turquoise,
    this.height = 60,
    this.fontSize,
    this.badge,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ButtonPalette palette;
  final double height;
  final double? fontSize;

  /// Small pill shown on the top-right corner (e.g. "YAKINDA").
  final String? badge;
  final bool expand;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final p = enabled ? widget.palette : ButtonPalette.disabled;
    final depth = (widget.height * 0.1).clamp(4.0, 7.0);
    final radius = widget.height * 0.36;
    final pressed = _down && enabled;

    final face = AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      margin: EdgeInsets.only(top: pressed ? depth : 0, bottom: pressed ? 0 : depth),
      height: widget.height - depth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.bottom],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Stack(
        children: [
          // Glossy top highlight.
          Positioned(
            left: radius * 0.5,
            right: radius * 0.5,
            top: 3,
            height: (widget.height - depth) * 0.36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: p.text, size: widget.height * 0.42),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: AppText.button.copyWith(
                        color: p.text,
                        fontSize: widget.fontSize ?? widget.height * 0.36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              _feedback(context);
              widget.onPressed!();
            }
          : null,
      child: SizedBox(
        height: widget.height,
        width: widget.expand ? double.infinity : null,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Depth layer.
            Positioned.fill(
              top: depth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: p.depth,
                  borderRadius: BorderRadius.circular(radius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.expand) Positioned.fill(child: face) else face,
            if (widget.badge != null)
              Positioned(right: -4, top: -10, child: SoonBadge(text: widget.badge!)),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      label: widget.label,
      enabled: enabled,
      child: PressScale(enabled: enabled, depth: 0.03, child: button),
    );
  }
}

/// Circular layered icon button with optional count badge and caption.
class RoundIconButton extends StatefulWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.palette = ButtonPalette.purple,
    this.size = 56,
    this.count,
    this.caption,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final ButtonPalette palette;
  final double size;

  /// Shown in a bubble on the corner. Use '+' to hint at buying more.
  final String? count;
  final String? caption;
  final String? tooltip;

  @override
  State<RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<RoundIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final p = enabled ? widget.palette : ButtonPalette.disabled;
    final s = widget.size;
    final depth = s * 0.08;
    final pressed = _down && enabled;

    final circle = SizedBox(
      width: s,
      height: s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: depth,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.depth,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 70),
            left: 0,
            right: 0,
            top: pressed ? depth : 0,
            height: s - depth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.3, -0.5),
                  radius: 1.0,
                  colors: [p.top, p.bottom],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(widget.icon, color: p.text, size: s * 0.48),
            ),
          ),
          if (widget.count != null)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                constraints: BoxConstraints(minWidth: s * 0.38),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  // A count on a disabled button is information, not an alert.
                  color: enabled ? AppColors.pink : const Color(0xFF6E6A94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: enabled ? 1 : 0.6), width: 1.5),
                ),
                child: Text(
                  widget.count!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapCancel: () => setState(() => _down = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _down = false);
              _feedback(context);
              widget.onPressed!();
            }
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          circle,
          if (widget.caption != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.caption!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(
                fontSize: AppSizes.minText,
                color: enabled ? AppColors.text : AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }
    return Semantics(
      button: true,
      label: widget.caption ?? widget.tooltip,
      enabled: enabled,
      child: PressScale(enabled: enabled, depth: 0.07, child: result),
    );
  }
}

/// Small "coming soon" style pill.
class SoonBadge extends StatelessWidget {
  const SoonBadge({super.key, this.text = 'YAKINDA'});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.pink, Color(0xFFFF8A5C)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Click sound + light haptic (respecting settings) for shared buttons.
void _feedback(BuildContext context) {
  AppScope.audioOf(context).play(Sfx.button);
  final scope = context.getInheritedWidgetOfExactType<AppScope>();
  if (scope?.notifier?.hapticsOn ?? true) HapticFeedback.lightImpact();
}
