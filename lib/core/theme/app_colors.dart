import 'package:flutter/material.dart';

/// Brand palette: navy, purple and turquoise.
abstract final class AppColors {
  // Backgrounds
  static const navy = Color(0xFF0F1640);
  static const indigo = Color(0xFF1E1A5E);
  static const purple = Color(0xFF3A1F7A);
  static const deepPurple = Color(0xFF251457);

  // Accents
  static const turquoise = Color(0xFF2EE6D6);
  static const turquoiseDark = Color(0xFF0FA3B5);
  static const violet = Color(0xFF9B6BFF);
  static const pink = Color(0xFFFF5C8A);
  static const gold = Color(0xFFFFC53D);
  static const goldDark = Color(0xFFE08A00);

  // Surfaces
  static const panel = Color(0x1FFFFFFF);
  static const panelBorder = Color(0x33FFFFFF);

  // Text
  static const text = Colors.white;
  static const textMuted = Color(0xFFB9B4EA);
  static const textDim = Color(0xFF8079C0);

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2B1B6E), Color(0xFF1B1858), Color(0xFF0D1A48)],
    stops: [0, 0.55, 1],
  );
}

/// Colors for a layered 3D button: top gradient + darker "depth" edge.
class ButtonPalette {
  const ButtonPalette(this.top, this.bottom, this.depth, {this.text = Colors.white});

  final Color top;
  final Color bottom;
  final Color depth;
  final Color text;

  static const turquoise = ButtonPalette(
    Color(0xFF5CF5E2),
    Color(0xFF14B8C9),
    Color(0xFF0A7A8F),
  );
  static const purple = ButtonPalette(
    Color(0xFFB58CFF),
    Color(0xFF7443F0),
    Color(0xFF4722A8),
  );
  static const gold = ButtonPalette(
    Color(0xFFFFE07A),
    Color(0xFFFFA928),
    Color(0xFFBF6A00),
    text: Color(0xFF5A2E00),
  );
  static const pink = ButtonPalette(
    Color(0xFFFF8AAA),
    Color(0xFFEF3F70),
    Color(0xFFA51F4A),
  );
  static const navy = ButtonPalette(
    Color(0xFF4B4C9E),
    Color(0xFF2E2D78),
    Color(0xFF1A1950),
  );
  static const disabled = ButtonPalette(
    Color(0xFF6E6A94),
    Color(0xFF4F4B78),
    Color(0xFF34315A),
    text: Color(0xFFC9C6E4),
  );
}
