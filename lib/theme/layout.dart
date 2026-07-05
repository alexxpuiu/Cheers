import 'package:flutter/widgets.dart';

/// Shared layout breakpoints for responsive UI.
abstract final class AppLayout {
  /// Viewports below this width behave like a phone (edge-to-edge overlays).
  static const double phoneBreakpoint = 600;

  /// Max width for the map POI detail card on wider viewports.
  static const double poiDetailCardMaxWidth = 400;

  static bool isPhoneWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width < phoneBreakpoint;
}
