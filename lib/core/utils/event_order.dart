import 'package:latlong2/latlong.dart';

import '../services/event_service.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when the exhibition has already opened on [today].
bool isRunning(ArtEvent event, DateTime today) => !_day(event.startDate).isAfter(_day(today));

/// Exhibitions running now come first, closing soonest at the top; then the
/// upcoming ones by opening date.
List<ArtEvent> orderForHome(List<ArtEvent> events, DateTime today) {
  final running = events.where((e) => isRunning(e, today)).toList()
    ..sort((a, b) => a.endDate.compareTo(b.endDate));
  final upcoming = events.where((e) => !isRunning(e, today)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return [...running, ...upcoming];
}

/// Kilometres from [origin] to the event's venue, or null when either is unknown.
double? distanceKm(ArtEvent event, LatLng? origin) {
  if (origin == null || event.location == null) return null;
  return const Distance().as(LengthUnit.Meter, origin, event.location!) / 1000;
}

/// Nearest venue first; events without a location follow in [orderForHome]
/// order. The sort is stable, so shows at the same venue keep that order too.
List<ArtEvent> orderByDistance(List<ArtEvent> events, LatLng origin, DateTime today) {
  final ordered = orderForHome(events, today);
  final located = ordered.where((e) => e.location != null).toList();
  final unknown = ordered.where((e) => e.location == null).toList();
  final keyed = [for (var i = 0; i < located.length; i++) (distanceKm(located[i], origin)!, i, located[i])]
    ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return [...keyed.map((k) => k.$3), ...unknown];
}
