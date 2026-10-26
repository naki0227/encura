import 'package:encura/core/services/event_service.dart';
import 'package:encura/core/utils/event_order.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

ArtEvent _event(String id, DateTime start, DateTime end, {LatLng? at}) =>
    ArtEvent(id: id, title: id, venue: 'v', location: at, startDate: start, endDate: end);

void main() {
  final today = DateTime(2026, 10, 26, 11, 53);

  test('running exhibitions first by closing date, then upcoming by opening date', () {
    final events = [
      _event('opens-dec', DateTime(2026, 12, 1), DateTime(2027, 3, 14)),
      _event('since-aug', DateTime(2026, 8, 1), DateTime(2026, 11, 23)),
      _event('opens-today', DateTime(2026, 10, 26), DateTime(2027, 1, 31)),
      _event('closes-soon', DateTime(2026, 9, 12), DateTime(2026, 11, 8)),
      _event('opens-nov', DateTime(2026, 11, 12), DateTime(2027, 1, 17)),
    ];
    expect(orderForHome(events, today).map((e) => e.id),
        ['closes-soon', 'since-aug', 'opens-today', 'opens-nov', 'opens-dec']);
  });

  test('an exhibition is running from its opening day', () {
    expect(isRunning(_event('a', DateTime(2026, 10, 26), DateTime(2026, 12, 1)), today), isTrue);
    expect(isRunning(_event('b', DateTime(2026, 10, 27), DateTime(2026, 12, 1)), today), isFalse);
  });

  test('nearest venue first; same venue keeps running-first order; unknown location last', () {
    const ueno = LatLng(35.7175, 139.7755);
    const osaka = LatLng(34.6926, 135.4898);
    final events = [
      _event('osaka', DateTime(2026, 10, 1), DateTime(2026, 11, 1), at: osaka),
      _event('nowhere', DateTime(2026, 10, 1), DateTime(2026, 10, 30)),
      _event('ueno-upcoming', DateTime(2026, 11, 3), DateTime(2026, 12, 1), at: ueno),
      _event('ueno-running', DateTime(2026, 10, 1), DateTime(2026, 12, 20), at: ueno),
    ];
    const tokyoStation = LatLng(35.6812, 139.7671);
    expect(orderByDistance(events, tokyoStation, today).map((e) => e.id),
        ['ueno-running', 'ueno-upcoming', 'osaka', 'nowhere']);
    expect(distanceKm(events[1], tokyoStation), isNull);
    expect(distanceKm(events[0], tokyoStation)!, closeTo(400, 10));
  });
}
