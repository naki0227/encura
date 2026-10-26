import '../models/art_knowledge.dart';

/// A suggested work and why it was suggested.
class Recommendation {
  final Artwork artwork;
  final String reason;
  final int score;

  const Recommendation({required this.artwork, required this.reason, required this.score});
}

/// Works to suggest from the ones the user marked with ♡.
///
/// Runs on the device only. A candidate scores for sharing a movement (3), an
/// artist (2), a movement linked to a favourite's (2) or an era within 50
/// years (1) with any favourite; the reason names its strongest tie.
List<Recommendation> recommend(ArtKnowledge knowledge, Set<String> favouriteIds, {int limit = 10}) {
  final favourites = knowledge.artworks.where((a) => favouriteIds.contains(a.id)).toList();
  if (favourites.isEmpty) return const [];

  final linked = <String, Set<String>>{};
  for (final l in knowledge.links) {
    linked.putIfAbsent(l.fromSlug, () => {}).add(l.toSlug);
    linked.putIfAbsent(l.toSlug, () => {}).add(l.fromSlug);
  }

  final results = <Recommendation>[];
  for (final candidate in knowledge.artworks) {
    if (favouriteIds.contains(candidate.id)) continue;
    var score = 0;
    var best = 0;
    var reason = '';
    void tie(int points, String why) {
      score += points;
      if (points > best) {
        best = points;
        reason = why;
      }
    }

    for (final f in favourites) {
      if (candidate.movementSlug != null && candidate.movementSlug == f.movementSlug) {
        tie(3, '「${f.title}」と同じ${knowledge.movement(f.movementSlug)?.nameJa ?? '流れ'}');
      } else if (candidate.movementSlug != null &&
          (linked[f.movementSlug] ?? const {}).contains(candidate.movementSlug)) {
        final m = knowledge.movement(candidate.movementSlug);
        tie(2, '「${f.title}」の流れとつながる${m?.nameJa ?? ''}');
      }
      if (candidate.artist == f.artist) tie(2, '「${f.title}」と同じ${f.artist}の作品');
      if (candidate.year != null && f.year != null && (candidate.year! - f.year!).abs() <= 50) {
        tie(1, '「${f.title}」と同じころの作品');
      }
    }
    if (score > 0) results.add(Recommendation(artwork: candidate, reason: reason, score: score));
  }
  results.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    return byScore != 0 ? byScore : a.artwork.title.compareTo(b.artwork.title);
  });
  return results.take(limit).toList();
}
