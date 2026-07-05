import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'map_panel.dart';

/// Small "Powered by Foursquare" pill.
///
/// Foursquare's TOS requires visible attribution on any screen that shows
/// their place data (ratings, photos, review counts). We render this on the
/// map screen; a single pill covers all POIs on that screen per their
/// aggregate-attribution guidance.
///
/// Uses [MapPanel] (not [GlassContainer]) so we don't reintroduce the iOS/web
/// full-screen frost bug from backdrop blur on map overlays.
class FoursquareAttribution extends StatelessWidget {
  const FoursquareAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return MapPanel(
      radius: 100,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      borderOpacity: 0.22,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place_outlined,
              size: 12, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            'Powered by Foursquare',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
