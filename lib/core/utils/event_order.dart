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
