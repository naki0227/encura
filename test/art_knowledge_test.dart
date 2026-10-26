import 'package:encura/core/models/art_knowledge.dart';
import 'package:flutter_test/flutter_test.dart';

Movement _movement(String slug, int start, {int? end}) => Movement(
      slug: slug,
      nameJa: slug,
      nameEn: slug,
      region: 'west',
      startYear: start,
      endYear: end,
      summary: '',
      body: '',
      sourceUrl: '',
    );

Artwork _work(String id, String artist, int? year, String movement) => Artwork(
      id: id,
      title: id,
      artist: artist,
      year: year,
      movementSlug: movement,
      collection: null,
      imageUrl: 'https://img/$id.jpg',
      content: '',
    );

void main() {
  final knowledge = ArtKnowledge(
    movements: [_movement('realism', 1840, end: 1880), _movement('impressionism', 1860, end: 1890), _movement('contemporary', 1970)],
    links: const [
      MovementLink(fromSlug: 'realism', toSlug: 'impressionism', kind: 'led_to', note: ''),
      MovementLink(fromSlug: 'impressionism', toSlug: 'contemporary', kind: 'influence', note: ''),
    ],
    artworks: [
      _work('sunrise', 'Monet', 1872, 'impressionism'),
      _work('undated', 'Morisot', null, 'impressionism'),
      _work('olympia', 'Manet', 1863, 'impressionism'),
      _work('stone', 'Courbet', 1849, 'realism'),
    ],
  );

  test('works of a movement come in time order, undated last', () {
    expect(knowledge.worksOf('impressionism').map((a) => a.id), ['olympia', 'sunrise', 'undated']);
    expect(knowledge.coverOf('impressionism'), 'https://img/olympia.jpg');
    expect(knowledge.coverOf('contemporary'), '');
  });

  test('links are read both ways', () {
    expect(knowledge.linksInto('impressionism').single.fromSlug, 'realism');
    expect(knowledge.linksOutOf('impressionism').single.toSlug, 'contemporary');
    expect(knowledge.linksInto('impressionism').single.kindLabel, '受け継ぐ');
  });

  test('periods read naturally, open-ended ones too', () {
    expect(knowledge.movement('realism')!.period, '1840–1880年ごろ');
    expect(knowledge.movement('contemporary')!.period, '1970年ごろ〜');
    expect(knowledge.movement('missing'), isNull);
  });
}
