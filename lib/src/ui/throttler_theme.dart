import 'package:flutter/material.dart';

/// Colour and type tokens for the [NetworkThrottlerPanel], taken from the
/// Network Throttler design. Kept internal so the panel has a consistent look
/// without imposing a theme on the host app.
class ThrottlerTokens {
  ThrottlerTokens._();

  // Surfaces
  static const Color background = Color(0xFFF4F5F7);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE6E8EC);
  static const Color divider = Color(0xFFF0F1F4);
  static const Color chipBorder = Color(0xFFE0E3E8);
  static const Color trackInactive = Color(0xFFE2E6EC);
  static const Color switchOff = Color(0xFFCBD0D8);

  // Text
  static const Color ink = Color(0xFF14181F);
  static const Color label = Color(0xFF8A93A0);
  static const Color muted = Color(0xFF9AA2AE);
  static const Color secondary = Color(0xFF6B7280);
  static const Color body = Color(0xFF3B4250);

  // Accents
  static const Color accent = Color(0xFF2D6CDF);
  static const Color green = Color(0xFF18A957);
  static const Color red = Color(0xFFE5484D);
  static const Color amber = Color(0xFFE8A317);
  static const Color teal = Color(0xFF0E9488);
  static const Color purple = Color(0xFF7A52E0);

  // Failure-card tint
  static const Color redTint = Color(0xFFFDECEC);
  static const Color redInk = Color(0xFFC5383C);

  /// Section heading: small, bold, wide-tracked, uppercase.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: label,
  );

  /// Monospace style for values, codes, and the log.
  static TextStyle mono({
    double size = 13,
    FontWeight weight = FontWeight.w600,
    Color color = ink,
  }) {
    return TextStyle(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Menlo', 'Roboto Mono', 'Courier New'],
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  /// Method-badge colour for the rules and log lists.
  static Color methodColor(String method) {
    final m = method.toUpperCase();
    if (m.startsWith('WS')) return purple;
    switch (m) {
      case 'GET':
        return teal;
      case 'POST':
        return accent;
      case 'DELETE':
        return red;
      case 'PUT':
        return amber;
      default:
        return secondary;
    }
  }
}
