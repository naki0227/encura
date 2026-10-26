import 'package:encura/core/models/art_knowledge.dart';
import 'package:encura/core/utils/recommend.dart';
import 'package:flutter_test/flutter_test.dart';

Movement _m(String slug) => Movement(
    slug: slug, nameJa: slug, nameEn: slug, region: 'west', startYear: 1800, endYear: null,
    summary: '', body: '', sourceUrl: '');

Artwork _a(String id, String artist, int? year, String movement) => Artwork(
    id: id, title: id, artist: artist, year: year, movementSlug: movement, collection: null, imageUrl: '', content: '');

void main() {
  final knowledge = ArtKnowledge(
    movements: [_m('ukiyo-e'), _m('impressionism'), _m('renaissance')],
    links: const [MovementLink(fromSlug: 'ukiyo-e', toSlug: 'impressionism', kind: 'influence', note: '')],
    artworks: [
      _a('wave', 'Hokusai', 1831, 'ukiyo-e'),
      _a('fuji', 'Hokusai', 1831, 'ukiyo-e'),
      _a('plum', 'Hiroshige', 1857, 'ukiyo-e'),
      _a('sunrise', 'Monet', 1872, 'impressionism'),
      _a('mona', 'Leonardo', 1503, 'renaissance'),
    ],
  );

  test('no favourites, no suggestions', () {
    expect(recommend(knowledge, {}), isEmpty);
  });

  test('same artist and movement first, then linked movements; unrelated works never', () {
    final recs = recommend(knowledge, {'wave'});
    expect(recs.map((r) => r.artwork.id), ['fuji', 'plum', 'sunrise']);
    expect(recs.first.reason, contains('ukiyo-e'));
    expect(recs.last.reason, contains('つながる'));
  });

  test('favourites themselves are not suggested', () {
    expect(recommend(knowledge, {'wave', 'fuji'}).map((r) => r.artwork.id), isNot(contains('fuji')));
  });
}
