import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum PoiCategory { accommodation, dining, sightseeing, nightlife }

extension PoiCategoryX on PoiCategory {
  String get label {
    switch (this) {
      case PoiCategory.accommodation:
        return 'Stay';
      case PoiCategory.dining:
        return 'Eat';
      case PoiCategory.sightseeing:
        return 'See';
      case PoiCategory.nightlife:
        return 'Night';
    }
  }

  IconData get icon {
    switch (this) {
      case PoiCategory.accommodation:
        return Icons.hotel_rounded;
      case PoiCategory.dining:
        return Icons.restaurant_rounded;
      case PoiCategory.sightseeing:
        return Icons.photo_camera_rounded;
      case PoiCategory.nightlife:
        return Icons.local_bar_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PoiCategory.accommodation:
        return AppColors.catAccommodation;
      case PoiCategory.dining:
        return AppColors.catDining;
      case PoiCategory.sightseeing:
        return AppColors.catSightseeing;
      case PoiCategory.nightlife:
        return AppColors.catNightlife;
    }
  }
}

class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.address,
    this.rating = 4.5,
    this.avgVisitMinutes = 60,
    this.opensAt = 9,
    this.closesAt = 22,
    this.blurb = '',
  });

  final String id;
  final String name;
  final PoiCategory category;
  final double lat;
  final double lng;
  final String address;
  final double rating;
  final int avgVisitMinutes;
  final int opensAt;
  final int closesAt;
  final String blurb;
}
