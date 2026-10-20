import 'package:encura/core/models/geo_point.dart';
import 'package:encura/core/services/event_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads GeoJSON', () {
    final p = parseGeoPoint({'type': 'Point', 'coordinates': [139.7, 35.7]})!;
    expect(p.latitude, 35.7);
    expect(p.longitude, 139.7);
  });

  test('reads WKT with or without SRID', () {
    expect(parseGeoPoint('POINT(139.7 35.7)')!.latitude, 35.7);
    expect(parseGeoPoint('SRID=4326;POINT(135.5 34.7)')!.longitude, 135.5);
  });

  test('reads hex EWKB as PostgREST returns geography columns', () {
    final p = parseGeoPoint('0101000020E610000089B48D3FD1786140388600E0D8DB4140')!;
    expect(p.latitude, closeTo(35.717556, 1e-9));
    expect(p.longitude, closeTo(139.775543, 1e-9));
    final be = parseGeoPoint('00000000014060f00000000000404159999999999a')!;
    expect(be.latitude, 34.7);
    expect(be.longitude, 135.5);
  });

  test('returns null instead of a default spot', () {
    expect(parseGeoPoint(null), isNull);
    expect(parseGeoPoint(''), isNull);
    expect(parseGeoPoint('POINT(abc def)'), isNull);
    expect(parseGeoPoint('POINT(500 35)'), isNull);
    expect(parseGeoPoint({'type': 'LineString', 'coordinates': []}), isNull);
    expect(parseGeoPoint('0102000000'), isNull);
  });

  test('ArtEvent keeps a missing location as null', () {
    final event = ArtEvent.fromJson({
      'id': '1',
      'title': 't',
      'venue': '東京国立博物館',
      'location': null,
      'start_date': '2026-10-01',
      'end_date': '2026-12-01',
    });
    expect(event.location, isNull);
  });
}
