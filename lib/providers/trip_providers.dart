import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/itinerary.dart';
import '../models/poi.dart';
import '../models/trip.dart';
import 'auth_providers.dart';
import 'poi_providers.dart';

/// In-memory list of trips visible to the current user.
///
/// Sourced from Supabase (`trips` + `trip_members` + `bucket_list_items`)
/// whenever an authed user is present. Sign-out clears the list. Bucket list
/// and anchor mutations are written through to Supabase and mirrored via
/// Realtime so co-planners see each other's picks live.
class TripStore extends ChangeNotifier {
  TripStore(this._ref) {
    _ref.listen<User?>(
      currentUserProvider,
      (previous, next) => _syncForUser(next),
      fireImmediately: true,
    );
    _ref.onDispose(_teardownRealtime);
  }

  final Ref _ref;
  final List<Trip> _trips = [];
  bool _loading = false;
  String? _error;

  RealtimeChannel? _bucketChannel;
  RealtimeChannel? _tripsChannel;

  List<Trip> get trips => List.unmodifiable(_trips);
  bool get isLoading => _loading;
  String? get error => _error;

  Trip byId(String id) => _trips.firstWhere((t) => t.id == id);

  Trip? tryById(String id) {
    for (final t in _trips) {
      if (t.id == id) return t;
    }
    return null;
  }

  // -------------------------------------------------------------------------
  // Sync
  // -------------------------------------------------------------------------

  Future<void> _syncForUser(User? user) async {
    if (user == null) {
      _teardownRealtime();
      _trips.clear();
      _loading = false;
      _error = null;
      notifyListeners();
      return;
    }
    await refresh();
    _setupRealtime();
  }

  Future<void> refresh() async {
    if (_ref.read(currentUserProvider) == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final fetched = await _ref.read(tripsRepositoryProvider).listMyTrips();
      _trips
        ..clear()
        ..addAll(fetched);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------------
  // Realtime — mirror `bucket_list_items` and `trips.anchor_poi_id` across
  // co-planners' devices. RLS on both tables restricts the payload stream to
  // trips the current user is a member of, so we can safely subscribe with
  // no client-side filter.
  // -------------------------------------------------------------------------

  void _setupRealtime() {
    _teardownRealtime();
    final SupabaseClient client;
    try {
      client = _ref.read(supabaseClientProvider);
    } catch (_) {
      // Supabase not configured — silently skip; local-only mode still works.
      return;
    }

    _bucketChannel = client
        .channel('public:bucket_list_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bucket_list_items',
          callback: (payload) => _applyBucketInsert(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'bucket_list_items',
          callback: (payload) => _applyBucketDelete(payload.oldRecord),
        )
        .subscribe();

    _tripsChannel = client
        .channel('public:trips')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'trips',
          callback: (payload) => _applyTripUpdate(payload.newRecord),
        )
        .subscribe();
  }

  void _teardownRealtime() {
    _bucketChannel?.unsubscribe();
    _tripsChannel?.unsubscribe();
    _bucketChannel = null;
    _tripsChannel = null;
  }

  void _applyBucketInsert(Map<String, dynamic> row) {
    final tripId = row['trip_id'] as String?;
    final poiId = row['poi_id'] as String?;
    if (tripId == null || poiId == null) return;
    final t = tryById(tripId);
    if (t == null) return;
    if (!t.bucketList.contains(poiId)) {
      t.bucketList.add(poiId);
      notifyListeners();
    }
  }

  void _applyBucketDelete(Map<String, dynamic> row) {
    final tripId = row['trip_id'] as String?;
    final poiId = row['poi_id'] as String?;
    if (tripId == null || poiId == null) return;
    final t = tryById(tripId);
    if (t == null) return;
    final changed = t.bucketList.remove(poiId);
    if (t.anchorPoiId == poiId) {
      t.anchorPoiId = null;
      notifyListeners();
      return;
    }
    if (changed) notifyListeners();
  }

  void _applyTripUpdate(Map<String, dynamic> row) {
    final id = row['id'] as String?;
    if (id == null) return;
    final t = tryById(id);
    if (t == null) return;
    var changed = false;
    final anchor = row['anchor_poi_id'] as String?;
    if (t.anchorPoiId != anchor) {
      t.anchorPoiId = anchor;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  Future<Trip> create({
    required String name,
    required String city,
    required TripMode mode,
    required DateTime start,
    required DateTime end,
  }) async {
    final gradient = _trips.length % 3;
    final created = await _ref.read(tripsRepositoryProvider).createTrip(
          name: name,
          city: city,
          mode: mode,
          start: start,
          end: end,
          coverGradient: gradient,
        );
    _trips.insert(0, created);
    notifyListeners();
    return created;
  }

  Future<Trip> joinWithCode(String code) async {
    final trip =
        await _ref.read(tripsRepositoryProvider).joinTripWithCode(code);
    _trips.removeWhere((t) => t.id == trip.id);
    _trips.insert(0, trip);
    notifyListeners();
    return trip;
  }

  // -------------------------------------------------------------------------
  // Bucket list / anchor
  //
  // Optimistic local update first (so the UI feels instant), then write to
  // Supabase. Realtime broadcasts back INSERT/DELETE events; the applicators
  // above are idempotent so a rebroadcast for our own write is a no-op. On
  // network failure we roll back the local change and surface an error.
  // -------------------------------------------------------------------------

  Future<void> toggleBucket(String tripId, String poiId) async {
    final t = tryById(tripId);
    if (t == null) return;
    final repo = _ref.read(tripsRepositoryProvider);
    if (t.bucketList.contains(poiId)) {
      final wasAnchor = t.anchorPoiId == poiId;
      t.bucketList.remove(poiId);
      if (wasAnchor) t.anchorPoiId = null;
      notifyListeners();
      try {
        await repo.removeBucketItem(tripId: tripId, poiExtId: poiId);
      } catch (e) {
        t.bucketList.add(poiId);
        if (wasAnchor) t.anchorPoiId = poiId;
        _error = e.toString();
        notifyListeners();
      }
    } else {
      t.bucketList.add(poiId);
      notifyListeners();
      try {
        await repo.addBucketItem(tripId: tripId, poiExtId: poiId);
      } catch (e) {
        t.bucketList.remove(poiId);
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> setAnchor(String tripId, String poiId) async {
    final t = tryById(tripId);
    if (t == null) return;
    final previousAnchor = t.anchorPoiId;
    final addedToBucket = !t.bucketList.contains(poiId);
    t.anchorPoiId = poiId;
    if (addedToBucket) t.bucketList.add(poiId);
    notifyListeners();
    try {
      await _ref.read(tripsRepositoryProvider).setAnchor(
            tripId: tripId,
            poiExtId: poiId,
          );
    } catch (e) {
      t.anchorPoiId = previousAnchor;
      if (addedToBucket) t.bucketList.remove(poiId);
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> removeFromBucket(String tripId, String poiId) async {
    final t = tryById(tripId);
    if (t == null) return;
    final wasAnchor = t.anchorPoiId == poiId;
    if (!t.bucketList.remove(poiId)) return;
    if (wasAnchor) t.anchorPoiId = null;
    notifyListeners();
    try {
      await _ref.read(tripsRepositoryProvider).removeBucketItem(
            tripId: tripId,
            poiExtId: poiId,
          );
      if (wasAnchor) {
        // Also clear the DB-side anchor since we just deleted its row.
        await _ref
            .read(tripsRepositoryProvider)
            .setAnchor(tripId: tripId, poiExtId: null);
      }
    } catch (e) {
      t.bucketList.add(poiId);
      if (wasAnchor) t.anchorPoiId = poiId;
      _error = e.toString();
      notifyListeners();
    }
  }
}

final tripStoreProvider =
    ChangeNotifierProvider<TripStore>((ref) => TripStore(ref));

final tripProvider = Provider.family<Trip, String>((ref, id) {
  final store = ref.watch(tripStoreProvider);
  return store.byId(id);
});

// ---------------------------------------------------------------------------
// Category filter (shared by the map screen)
// ---------------------------------------------------------------------------

final categoryFilterProvider =
    StateNotifierProvider<CategoryFilter, Set<PoiCategory>>(
        (ref) => CategoryFilter());

class CategoryFilter extends StateNotifier<Set<PoiCategory>> {
  CategoryFilter() : super(PoiCategory.values.toSet());

  void toggle(PoiCategory c) {
    final next = {...state};
    if (next.contains(c)) {
      next.remove(c);
    } else {
      next.add(c);
    }
    state = next;
  }
}

// ---------------------------------------------------------------------------
// Itinerary generator — nearest-neighbour heuristic anchored on the
// accommodation, spread across trip days.
// ---------------------------------------------------------------------------

Itinerary generateItinerary(Trip trip, PoiCatalog catalog) {
  final ids = List<String>.from(trip.bucketList);
  final anchorId = trip.anchorPoiId ?? ids.firstOrNull;
  if (anchorId == null || ids.isEmpty) return const Itinerary(stops: []);

  final anchor = catalog.require(anchorId);
  final pois =
      ids.where((id) => id != anchorId).map(catalog.require).toList();

  // Avoid back-to-back same-category stops by interleaving.
  pois.sort((a, b) => a.category.index.compareTo(b.category.index));

  final days = math.max(1, trip.days);
  final chunks = List.generate(days, (_) => <Poi>[]);
  for (var i = 0; i < pois.length; i++) {
    chunks[i % days].add(pois[i]);
  }

  final stops = <ItineraryStop>[];
  for (var d = 0; d < days; d++) {
    // Order this day by nearest-neighbour from the anchor.
    final remaining = List<Poi>.from(chunks[d]);
    final ordered = <Poi>[];
    var current = anchor;
    while (remaining.isNotEmpty) {
      remaining.sort(
          (a, b) => _dist(current, a).compareTo(_dist(current, b)));
      final next = remaining.removeAt(0);
      ordered.add(next);
      current = next;
    }

    // Schedule times: start at 09:30, use avg_visit_minutes plus 25 min travel.
    var cursor = DateTime(2024, 1, 1, 9, 30);
    var seq = 0;
    // Anchor start
    stops.add(ItineraryStop(
      poiId: anchor.id,
      dayNumber: d + 1,
      sequence: seq++,
      arrival: cursor,
      departure: cursor,
    ));
    cursor = cursor.add(const Duration(minutes: 25));
    for (final p in ordered) {
      final arrival = cursor;
      final departure = arrival.add(Duration(minutes: p.avgVisitMinutes));
      stops.add(ItineraryStop(
        poiId: p.id,
        dayNumber: d + 1,
        sequence: seq++,
        arrival: arrival,
        departure: departure,
      ));
      cursor = departure.add(const Duration(minutes: 25));
    }
    // Anchor return
    stops.add(ItineraryStop(
      poiId: anchor.id,
      dayNumber: d + 1,
      sequence: seq++,
      arrival: cursor,
      departure: cursor,
    ));
  }
  return Itinerary(stops: stops);
}

double _dist(Poi a, Poi b) {
  final dx = a.lat - b.lat;
  final dy = a.lng - b.lng;
  return math.sqrt(dx * dx + dy * dy);
}

/// Cached last-generated itinerary per trip (kept in-memory so the map
/// and itinerary screens can share the same generation result).
final itineraryProvider =
    StateNotifierProvider.family<ItineraryController, Itinerary?, String>(
        (ref, tripId) => ItineraryController());

class ItineraryController extends StateNotifier<Itinerary?> {
  ItineraryController() : super(null);

  Future<void> regenerate(Trip trip, PoiCatalog catalog) async {
    // Small artificial delay so the "generating…" overlay reads.
    await Future.delayed(const Duration(milliseconds: 900));
    state = generateItinerary(trip, catalog);
  }

  void clear() => state = null;
}
