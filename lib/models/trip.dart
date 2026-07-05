enum TripMode { solo, group }

class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.city,
    required this.mode,
    required this.startDate,
    required this.endDate,
    this.ownerId,
    this.joinCode,
    this.anchorPoiId,
    List<String>? bucketList,
    this.coverGradient = 0,
    this.memberCount = 1,
  }) : bucketList = bucketList ?? <String>[];

  final String id;
  final String? ownerId;
  String name;
  String city;
  TripMode mode;
  DateTime startDate;
  DateTime endDate;
  String? anchorPoiId;
  String? joinCode;
  final List<String> bucketList;
  final int coverGradient;
  int memberCount;

  int get days => endDate.difference(startDate).inDays + 1;

  /// Deserialise a row from the `trips` Supabase table.
  ///
  /// Expects an optional nested `trip_members` array (from
  /// `select('*, trip_members(user_id)')`) so we can compute `memberCount`
  /// without a second round-trip. Same treatment for `bucket_list_items` —
  /// if the caller included it in the select, we hydrate `bucketList` from
  /// the nested rows so the map screen shows shared picks immediately.
  factory Trip.fromMap(Map<String, dynamic> row) {
    final members = row['trip_members'];
    final memberCount = members is List && members.isNotEmpty
        ? members.length
        : 1;

    final bucketRows = row['bucket_list_items'];
    final bucket = <String>[
      if (bucketRows is List)
        for (final b in bucketRows)
          if (b is Map && b['poi_id'] is String) b['poi_id'] as String,
    ];

    final modeStr = (row['mode'] as String?) ?? 'solo';
    return Trip(
      id: row['id'] as String,
      ownerId: row['owner_id'] as String?,
      name: row['name'] as String,
      city: (row['city'] as String?) ?? '',
      mode: modeStr == 'group' ? TripMode.group : TripMode.solo,
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: DateTime.parse(row['end_date'] as String),
      anchorPoiId: row['anchor_poi_id'] as String?,
      joinCode: row['join_code'] as String?,
      bucketList: bucket,
      coverGradient: (row['cover_gradient'] as int?) ?? 0,
      memberCount: memberCount,
    );
  }
}
