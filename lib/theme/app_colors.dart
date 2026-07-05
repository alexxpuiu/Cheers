import 'package:flutter/material.dart';

/// Cheers colour system — a warm, dusk-lit palette that reads well
/// behind frosted-glass surfaces.
class AppColors {
  AppColors._();

  // Base gradient — deep night sky sliding into warm coral horizon
  static const Color bgDeep = Color(0xFF0B0B1E);
  static const Color bgMid = Color(0xFF321B4E);
  static const Color bgWarm = Color(0xFFE8735A);
  static const Color bgHighlight = Color(0xFFFFB27A);

  // Accent — warm amber "cheers"
  static const Color accent = Color(0xFFFFB86B);
  static const Color accentSoft = Color(0xFFFFD8A8);

  // Category colours (POI markers)
  static const Color catAccommodation = Color(0xFF7C5CFF); // violet
  static const Color catDining = Color(0xFFFF6B8A); // rose
  static const Color catSightseeing = Color(0xFF4FD1C5); // teal
  static const Color catNightlife = Color(0xFFFFB86B); // amber

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xCCFFFFFF);
  static const Color textMuted = Color(0x99FFFFFF);

  // Glass
  static const Color glassFill = Color(0x1FFFFFFF); // ~12% white
  static const Color glassFillStrong = Color(0x33FFFFFF); // ~20% white
  static const Color glassBorder = Color(0x40FFFFFF); // ~25% white
  static const Color glassShadow = Color(0x33000000);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, bgMid, bgWarm],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB86B), Color(0xFFFF6B8A)],
  );
}
