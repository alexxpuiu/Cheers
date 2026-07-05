import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trip.dart';

/// Thin data layer over the `trips` / `trip_members` tables and the
/// `join_trip_with_code` RPC. All calls are RLS-guarded server-side, so this
/// class just marshals JSON to/from [Trip].
class TripsRepository {
  TripsRepository(this._client);

  final SupabaseClient _client;

  static const _tripSelect =
      '*, trip_members(user_id), bucket_list_items(poi_id)';

  /// Every trip the signed-in user owns OR is a member of.
  /// RLS on `trips` filters automatically via `is_trip_member(id)`.
  Future<List<Trip>> listMyTrips() async {
    final rows = await _client
        .from('trips')
        .select(_tripSelect)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Trip.fromMap)
        .toList();
  }

  Future<Trip?> getTrip(String id) async {
    final row = await _client
        .from('trips')
        .select(_tripSelect)
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Trip.fromMap(row);
  }

  /// Creates a trip owned by the current user via the `create_trip` RPC.
  ///
  /// We route through a SECURITY DEFINER function instead of a direct INSERT
  /// because RLS on `public.trips` needs `owner_id = auth.uid()` — that check
  /// silently fails in projects where the init migration didn't fully apply
  /// (e.g. Studio truncated the paste) and leaves anonymous users unable to
  /// create any trip at all. See `supabase/migrations/20260705140000_*`.
  Future<Trip> createTrip({
    required String name,
    required String city,
    required TripMode mode,
    required DateTime start,
    required DateTime end,
    int coverGradient = 0,
  }) async {
    if (_client.auth.currentUser?.id == null) {
      throw StateError('Cannot create a trip while signed out.');
    }

    final row = await _client.rpc(
      'create_trip',
      params: {
        'p_name': name,
        'p_city': city,
        'p_mode': mode == TripMode.group ? 'group' : 'solo',
        'p_start_date': _dateOnly(start),
        'p_end_date': _dateOnly(end),
        'p_cover_gradient': coverGradient,
      },
    );

    if (row == null) {
      throw StateError('create_trip returned no row.');
    }

    // The RPC returns the raw `trips` row (no join to trip_members). Re-fetch
    // via `getTrip` so we get the standard `_tripSelect` shape (member list)
    // that the rest of the app expects.
    final map = Map<String, dynamic>.from(row as Map);
    final tripId = map['id'] as String;
    final hydrated = await getTrip(tripId);
    return hydrated ?? Trip.fromMap(map);
  }

  /// Calls the `join_trip_with_code` RPC, then fetches the joined trip.
  /// Throws [TripJoinException] with a friendly message on bad code / auth.
  Future<Trip> joinTripWithCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) {
      throw const TripJoinException('Enter a code first.');
    }

    try {
      final tripId = await _client.rpc(
        'join_trip_with_code',
        params: {'p_code': code},
      );
      if (tripId == null) {
        throw const TripJoinException('Could not join that trip.');
      }
      final trip = await getTrip(tripId as String);
      if (trip == null) {
        throw const TripJoinException('Trip joined but could not be loaded.');
      }
      return trip;
    } on PostgrestException catch (e) {
      // P0002 is the "No trip found for code" we raise from the SQL function.
      if (e.code == 'P0002' || (e.message).contains('No trip found')) {
        throw TripJoinException('No trip with code $code.');
      }
      if (e.code == '28000') {
        throw const TripJoinException('You need to be signed in first.');
      }
      throw TripJoinException(e.message);
    }
  }

  // ---------------------------------------------------------------------------
  // Bucket list
  // ---------------------------------------------------------------------------
  //
  // `bucket_list_items.poi_id` is a plain `text` column (see the
  // 20260705150000 migration) so it can hold the mobile client's local POI
  // ids (`p1`…`p16`) instead of Supabase-generated uuids. RLS on the table
  // guards writes by trip membership.

  /// Insert a POI into the shared bucket list. Idempotent via
  /// `ON CONFLICT DO NOTHING` on the server-side unique key.
  Future<void> addBucketItem({
    required String tripId,
    required String poiExtId,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client
        .from('bucket_list_items')
        .upsert(
          {
            'trip_id': tripId,
            'poi_id': poiExtId,
            if (uid != null) 'added_by': uid,
          },
          onConflict: 'trip_id,poi_id',
          ignoreDuplicates: true,
        );
  }

  /// Remove a POI from the shared bucket list. Safe to call on rows that
  /// don't exist — the delete just no-ops.
  Future<void> removeBucketItem({
    required String tripId,
    required String poiExtId,
  }) async {
    await _client
        .from('bucket_list_items')
        .delete()
        .eq('trip_id', tripId)
        .eq('poi_id', poiExtId);
  }

  /// Set (or clear) the trip's accommodation anchor. Routed through the
  /// `set_trip_anchor` RPC so non-owner members can still update it — the
  /// direct `trips` UPDATE is owner-only by RLS. Passing `null` clears it.
  Future<void> setAnchor({
    required String tripId,
    required String? poiExtId,
  }) async {
    await _client.rpc(
      'set_trip_anchor',
      params: {
        'p_trip_id': tripId,
        'p_poi_ext_id': poiExtId,
      },
    );
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

class TripJoinException implements Exception {
  const TripJoinException(this.message);
  final String message;
  @override
  String toString() => message;
}
