import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/mock_pois.dart';
import '../models/itinerary.dart';
import '../models/poi.dart';
import '../models/trip.dart';

const _uuid = Uuid();

class TripStore extends ChangeNotifier {
  final List<Trip> _trips = [];

  List<Trip> get trips => List.unmodifiable(_trips);

  TripStore() {
    // Seed with one sample trip so the home screen looks alive on first
    // launch.
    final now = DateTime.now();
    final seed = Trip(
      id: _uuid.v4(),
      name: 'Barcelona long weekend',
      city: MockPois.demoCity,
      mode: TripMode.group,
      startDate: DateTime(now.year, now.month, now.day + 12),
      endDate: DateTime(now.year, now.month, now.day + 15),
      anchorPoiId: 'p1',
      bucketList: ['p1', 'p4', 'p6', 'p10', 'p14', 'p8'],
      coverGradient: 0,
      memberCount: 4,
    );
    _trips.add(seed);
  }

  Trip create({
    required String name,
    required String city,
    required TripMode mode,
    required DateTime start,
    required DateTime end,
  }) {
    final t = Trip(
      id: _uuid.v4(),
      name: name,
      city: city,
      mode: mode,
      startDate: start,
      endDate: end,
      coverGradient: _trips.length % 3,
      memberCount: mode == TripMode.group ? 2 : 1,
    );
    _trips.insert(0, t);
    notifyListeners();
    return t;
  }

  Trip byId(String id) => _trips.firstWhere((t) => t.id == id);

  void toggleBucket(String tripId, String poiId) {
    final t = byId(tripId);
    if (t.bucketList.contains(poiId)) {
      t.bucketList.remove(poiId);
      if (t.anchorPoiId == poiId) t.anchorPoiId = null;
    } else {
      t.bucketList.add(poiId);
    }
    notifyListeners();
  }

  void setAnchor(String tripId, String poiId) {
    final t = byId(tripId);
    t.anchorPoiId = poiId;
    if (!t.bucketList.contains(poiId)) t.bucketList.add(poiId);
    notifyListeners();
  }

  void removeFromBucket(String tripId, String poiId) {
    final t = byId(tripId);
    t.bucketList.remove(poiId);
    if (t.anchorPoiId == poiId) t.anchorPoiId = null;
    notifyListeners();
  }
}

final tripStoreProvider = ChangeNotifierProvider<TripStore>((ref) => TripStore());

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

Itinerary generateItinerary(Trip trip) {
  final ids = List<String>.from(trip.bucketList);
  final anchorId = trip.anchorPoiId ?? ids.firstOrNull;
  if (anchorId == null || ids.isEmpty) return const Itinerary(stops: []);

  final anchor = MockPois.byId(anchorId);
  final pois = ids.where((id) => id != anchorId).map(MockPois.byId).toList();

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

  Future<void> regenerate(Trip trip) async {
    // Small artificial delay so the "generating…" overlay reads.
    await Future.delayed(const Duration(milliseconds: 900));
    state = generateItinerary(trip);
  }

  void clear() => state = null;
}
