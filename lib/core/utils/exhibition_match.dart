import '../models/art_knowledge.dart';
import '../services/event_service.dart';

/// Where an exhibition is in its run, as of [today].
enum ExhibitionStatus { running, upcoming, ended }

ExhibitionStatus statusOf(ArtEvent event, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (event.endDate.isBefore(day)) return ExhibitionStatus.ended;
  if (event.startDate.isAfter(day)) return ExhibitionStatus.upcoming;
  return ExhibitionStatus.running;
}

/// Words an exhibition would use for this artist: the full name, the name
/// exhibitions usually use ("モネ", "北斎"), and the family name of a
/// katakana name ("ルノワール" from "ピエール＝オーギュスト・ルノワール").
List<String> artistKeys(String name, Artist? profile) {
  final keys = {name};
  final short = profile?.shortName;
  if (short != null && short.isNotEmpty) keys.add(short);
  final parts = name.split(RegExp(r'[・＝=]'));
  if (parts.length > 1 && RegExp(r'^[゠-ヿ]+$').hasMatch(parts.last)) keys.add(parts.last);
  return keys.where((k) => k.length >= 2).toList();
}

/// Exhibitions whose title or summary names any of [keys]: running ones
/// first (closing soonest), then upcoming (opening soonest), then ended
/// (most recent first).
List<ArtEvent> exhibitionsNaming(List<ArtEvent> events, Iterable<String> keys, DateTime today, {int limit = 6}) {
  final words = keys.where((k) => k.length >= 2).toSet();
  if (words.isEmpty) return const [];
  final hits = events.where((e) {
    final text = '${e.title} ${e.summary ?? ''}';
    return words.any(text.contains);
  }).toList();
  int rank(ArtEvent e) => statusOf(e, today).index;
  hits.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return switch (statusOf(a, today)) {
      ExhibitionStatus.running => a.endDate.compareTo(b.endDate),
      ExhibitionStatus.upcoming => a.startDate.compareTo(b.startDate),
      ExhibitionStatus.ended => b.endDate.compareTo(a.endDate),
    };
  });
  return hits.take(limit).toList();
}
