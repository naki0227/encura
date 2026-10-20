import 'package:encura/core/utils/search_filter.dart';
import 'package:encura/core/utils/venue_sort.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('search filter quotes user input so commas and parentheses stay text', () {
    expect(ilikeAnyFilter(['title', 'artist'], 'モネ'), 'title.ilike."%モネ%",artist.ilike."%モネ%"');
    expect(ilikeAnyFilter(['title'], '睡蓮, (1906)'), 'title.ilike."%睡蓮, (1906)%"');
    expect(ilikeAnyFilter(['title'], r'a"b\c'), r'title.ilike."%a\"b\\c%"');
  });

  test('nearby venues are sorted by distance, unknown locations last', () {
    final venues = [
      {'name': 'unknown', 'location': null},
      {'name': 'osaka', 'location': 'POINT(135.4898 34.6926)'},
      {'name': 'ueno', 'location': {'type': 'Point', 'coordinates': [139.7755, 35.7175]}},
    ];
    final tokyoStation = const LatLng(35.6812, 139.7671);
    expect(sortByDistance(venues, tokyoStation).map((v) => v['name']), ['ueno', 'osaka', 'unknown']);
  });
}
