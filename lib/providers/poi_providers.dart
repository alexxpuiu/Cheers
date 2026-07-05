import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/poi.dart';
import '../services/pois_repository.dart';
import 'auth_providers.dart';

/// Read-only catalog of Barcelona POIs, sourced from `public.pois`.
///
/// The catalog is small (< 200 rows) and stable within a session, so we load
/// it once behind a [FutureProvider] and hand out an in-memory map keyed by
/// UUID for O(1) lookups from the map, itinerary, and bucket-list widgets.
class PoiCatalog {
  PoiCatalog(this.list)
      : _byId = {for (final p in list) p.id: p};

  const PoiCatalog.empty()
      : list = const [],
        _byId = const {};

  final List<Poi> list;
  final Map<String, Poi> _byId;

  bool get isEmpty => list.isEmpty;
  bool get isNotEmpty => list.isNotEmpty;
  int get length => list.length;

  Poi? byId(String id) => _byId[id];

  /// Non-null lookup. Returns a stub POI when the id isn't in the catalog —
  /// keeps the UI rendering (with "Unknown place") instead of throwing while
  /// a bucket list references a stale/legacy id (e.g. the old mock catalog).
  Poi require(String id) => _byId[id] ?? _stub(id);

  static Poi _stub(String id) => Poi(
        id: id,
        name: 'Unknown place',
        category: PoiCategory.sightseeing,
        lat: BarcelonaCenter.lat,
        lng: BarcelonaCenter.lng,
        address: '',
      );
}

/// Where the map opens by default when a trip has no bookmarks yet.
class BarcelonaCenter {
  const BarcelonaCenter._();

  static const String city = 'Barcelona';
  static const double lat = 41.3874;
  static const double lng = 2.1686;
}

final poisRepositoryProvider = Provider<PoisRepository>(
  (ref) => PoisRepository(ref.watch(supabaseClientProvider)),
);

/// Loads all POIs on first read and caches them for the lifetime of the app.
/// Depends on [currentUserProvider] because the `pois` SELECT policy is
/// `to authenticated using (true)` — we can't fetch until the user has a
/// session.
final poiCatalogProvider = FutureProvider<PoiCatalog>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const PoiCatalog.empty();
  final list = await ref.read(poisRepositoryProvider).listAll();
  return PoiCatalog(list);
});
