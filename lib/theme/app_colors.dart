import 'package:flutter/material.dart';

/// Cheers colour system — warm cream base with amber accents.
class AppColors {
  AppColors._();

  // Base gradient — soft sunrise cream into warm blush
  static const Color bgDeep = Color(0xFFFFFAF6);
  static const Color bgMid = Color(0xFFFFEFE4);
  static const Color bgWarm = Color(0xFFFFD9C2);
  static const Color bgHighlight = Color(0xFFFFB89A);
  static const Color bgSurface = Color(0xFFFFFFFF);

  // Accent — warm amber "cheers"
  static const Color accent = Color(0xFFE8952E);
  static const Color accentSoft = Color(0xFFFFD8A8);

  // Category colours (POI markers)
  static const Color catAccommodation = Color(0xFF7C5CFF);
  static const Color catDining = Color(0xFFFF6B8A);
  static const Color catSightseeing = Color(0xFF4FD1C5);
  static const Color catNightlife = Color(0xFFE8952E);

  // Text
  static const Color textPrimary = Color(0xFF1C1528);
  static const Color textSecondary = Color(0xB31C1528);
  static const Color textMuted = Color(0x801C1528);

  // Text/icons on accent gradients
  static const Color onAccent = Color(0xFFFFFFFF);

  // Glass — dark tint on light surfaces
  static const Color glassFill = Color(0x141C1528);
  static const Color glassFillStrong = Color(0x261C1528);
  static const Color glassBorder = Color(0x331C1528);
  static const Color glassShadow = Color(0x1A000000);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, bgMid, bgWarm],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8952E), Color(0xFFFF6B8A)],
  );
}
