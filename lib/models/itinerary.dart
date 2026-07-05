class ItineraryStop {
  const ItineraryStop({
    required this.poiId,
    required this.dayNumber,
    required this.sequence,
    required this.arrival,
    required this.departure,
  });

  final String poiId;
  final int dayNumber;
  final int sequence;
  final DateTime arrival;
  final DateTime departure;
}

class Itinerary {
  const Itinerary({required this.stops});

  final List<ItineraryStop> stops;

  Iterable<int> get dayNumbers =>
      (stops.map((s) => s.dayNumber).toSet().toList()..sort());

  List<ItineraryStop> forDay(int day) =>
      stops.where((s) => s.dayNumber == day).toList()
        ..sort((a, b) => a.sequence.compareTo(b.sequence));
}
