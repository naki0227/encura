import 'package:latlong2/latlong.dart';

import '../models/geo_point.dart';

/// Venues ordered by distance from [origin]; venues without a known
/// location keep their order at the end of the list.
List<Map<String, dynamic>> sortByDistance(List<Map<String, dynamic>> venues, LatLng origin) {
  const distance = Distance();
  final located = <(double, Map<String, dynamic>)>[];
  final unknown = <Map<String, dynamic>>[];
  for (final venue in venues) {
    final point = parseGeoPoint(venue['location']);
    if (point == null) {
      unknown.add(venue);
    } else {
      located.add((distance(origin, point), venue));
    }
  }
  located.sort((a, b) => a.$1.compareTo(b.$1));
  return [...located.map((e) => e.$2), ...unknown];
}
