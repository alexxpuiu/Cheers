enum TripMode { solo, group }

class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.city,
    required this.mode,
    required this.startDate,
    required this.endDate,
    this.anchorPoiId,
    List<String>? bucketList,
    this.coverGradient = 0,
    this.memberCount = 1,
  }) : bucketList = bucketList ?? <String>[];

  final String id;
  String name;
  String city;
  TripMode mode;
  DateTime startDate;
  DateTime endDate;
  String? anchorPoiId;
  final List<String> bucketList;
  final int coverGradient;
  int memberCount;

  int get days => endDate.difference(startDate).inDays + 1;
}
