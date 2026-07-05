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
    this.ratingCount = 0,
    this.photos = const [],
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
  final int ratingCount;
  final List<PoiPhoto> photos;
  final int avgVisitMinutes;
  final int opensAt;
  final int closesAt;
  final String blurb;
}

/// A cached photo reference for a POI detail card.
///
/// Two shapes are supported in `public.pois.photos` jsonb:
///   • **Wikimedia** — `{source, url, width?, height?, attribution?}` with a
///     ready-to-fetch thumbnail URL from Wikipedia / Commons.
///   • **Foursquare** — `{prefix, suffix, width?, height?}`; the client
///     composes URLs as `${prefix}${size}${suffix}` at render time.
class PoiPhoto {
  const PoiPhoto({
    this.id,
    this.prefix = '',
    this.suffix = '',
    this.directUrl,
    this.source,
    this.attribution,
    this.width,
    this.height,
  });

  final String? id;
  final String prefix;
  final String suffix;

  /// Direct image URL (Wikimedia and other non-Foursquare sources).
  final String? directUrl;

  /// Provenance tag, e.g. `wikimedia` or `foursquare`.
  final String? source;

  /// Human-readable credit line for CC-licensed images.
  final String? attribution;

  final int? width;
  final int? height;

  bool get isWikimedia => source == 'wikimedia';

  bool get isFoursquare =>
      source == 'foursquare' || (directUrl == null && prefix.isNotEmpty);

  /// Build a photo URL at the requested size token.
  ///
  /// For direct URLs (Wikimedia), returns [directUrl] unchanged — the
  /// thumbnail is already sized when we baked it into the migration.
  ///
  /// For Foursquare, `size` may be `original`, `WIDTHxHEIGHT` (e.g.
  /// `600x400`), etc.
  String url({String size = 'original'}) {
    if (directUrl != null && directUrl!.isNotEmpty) return directUrl!;
    return '$prefix$size$suffix';
  }
}
