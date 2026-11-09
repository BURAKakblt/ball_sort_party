import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'game_button.dart';

/// Action shown at the bottom of a [showGameDialog].
class DialogAction<T> {
  const DialogAction(this.label, this.value, {this.palette = ButtonPalette.turquoise, this.icon});

  final String label;
  final T value;
  final ButtonPalette palette;
  final IconData? icon;
}

/// Styled modal with a pop-in animation. Returns the chosen action value.
Future<T?> showGameDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  Widget? content,
  Widget? header,
  List<DialogAction<T>> actions = const [],
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: const Color(0xAA070420),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, _, _) => GameDialog<T>(
      title: title,
      message: message,
      content: content,
      header: header,
      actions: actions,
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class GameDialog<T> extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    this.message,
    this.content,
    this.header,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final Widget? content;
  final Widget? header;
  final List<DialogAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            type: MaterialType.transparency,
            child: GameCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (header != null) ...[header!, const SizedBox(height: 10)],
                  Text(title, textAlign: TextAlign.center, style: AppText.heading),
                  if (message != null) ...[
                    const SizedBox(height: 10),
                    Text(message!, textAlign: TextAlign.center, style: AppText.body),
                  ],
                  if (content != null) ...[const SizedBox(height: 14), content!],
                  if (actions.isNotEmpty) const SizedBox(height: 20),
                  for (final a in actions) ...[
                    GameButton(
                      label: a.label,
                      icon: a.icon,
                      palette: a.palette,
                      height: 52,
                      onPressed: () => Navigator.of(context).pop(a.value),
                    ),
                    if (a != actions.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Solid modal card used by dialogs and overlays.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4A2D9E), Color(0xFF2A1B70), Color(0xFF1C1655)],
        ),
        border: Border.all(color: AppColors.violet.withValues(alpha: 0.7), width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.violet.withValues(alpha: 0.35), blurRadius: 30),
          const BoxShadow(color: Color(0x88000000), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: child,
    );
  }
}

void showToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 1600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
}
