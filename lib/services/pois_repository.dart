import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/poi.dart';

/// Thin data layer over the `public.pois` catalog.
///
/// The seed migration (`20260705160000_seed_real_pois.sql`) hydrates this
/// table from Mapbox's Search Box API around Barcelona. We keep the catalog
/// read-only from the client for now — POI creation would open the door to
/// abuse without moderation, and the app's editorial voice depends on a
/// curated set.
class PoisRepository {
  PoisRepository(this._client);

  final SupabaseClient _client;

  Future<List<Poi>> listAll() async {
    final rows = await _client
        .from('pois')
        .select()
        .order('name');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_fromMap)
        .toList(growable: false);
  }

  static Poi _fromMap(Map<String, dynamic> row) {
    final categoryStr = (row['category'] as String?) ?? 'sightseeing';
    final category = PoiCategory.values.firstWhere(
      (c) => c.name == categoryStr,
      orElse: () => PoiCategory.sightseeing,
    );
    return Poi(
      id: row['id'] as String,
      name: row['name'] as String,
      category: category,
      lat: (row['lat'] as num).toDouble(),
      lng: (row['lng'] as num).toDouble(),
      address: (row['address'] as String?) ?? '',
      rating: ((row['rating'] as num?) ?? 4.5).toDouble(),
      ratingCount: (row['review_count'] as int?) ?? 0,
      photos: _photosFrom(row['photos']),
      avgVisitMinutes: (row['avg_visit_minutes'] as int?) ?? 60,
      opensAt: (row['opens_at'] as int?) ?? 9,
      closesAt: (row['closes_at'] as int?) ?? 22,
      blurb: (row['blurb'] as String?) ?? '',
    );
  }

  static List<PoiPhoto> _photosFrom(dynamic raw) {
    if (raw is! List) return const [];
    final out = <PoiPhoto>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final directUrl = entry['url'];
      if (directUrl is String && directUrl.isNotEmpty) {
        out.add(PoiPhoto(
          id: entry['id'] as String?,
          directUrl: directUrl,
          source: entry['source'] as String?,
          attribution: entry['attribution'] as String?,
          width: (entry['width'] as num?)?.toInt(),
          height: (entry['height'] as num?)?.toInt(),
        ));
        continue;
      }
      final prefix = entry['prefix'];
      final suffix = entry['suffix'];
      if (prefix is! String || suffix is! String) continue;
      out.add(PoiPhoto(
        id: entry['id'] as String?,
        prefix: prefix,
        suffix: suffix,
        source: (entry['source'] as String?) ?? 'foursquare',
        width: (entry['width'] as num?)?.toInt(),
        height: (entry['height'] as num?)?.toInt(),
      ));
    }
    return out;
  }
}
