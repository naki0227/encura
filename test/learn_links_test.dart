import 'dart:math';

import 'package:encura/core/models/art_knowledge.dart';
import 'package:encura/core/services/event_service.dart';
import 'package:encura/core/utils/exhibition_match.dart';
import 'package:encura/core/utils/quiz.dart';
import 'package:flutter_test/flutter_test.dart';

Movement movement(String slug, String region, int start, int? end) => Movement(
      slug: slug,
      nameJa: slug,
      nameEn: slug,
      region: region,
      startYear: start,
      endYear: end,
      summary: '',
      body: '',
      sourceUrl: '',
    );

Artwork work(String id, String artist, int year, String slug) => Artwork(
      id: id,
      title: 'title $id',
      artist: artist,
      year: year,
      movementSlug: slug,
      collection: null,
      imageUrl: 'https://example.com/$id.jpg',
      content: '',
    );

ArtEvent event(String title, String start, String end) => ArtEvent(
      id: title,
      title: title,
      venue: '美術館',
      startDate: DateTime.parse(start),
      endDate: DateTime.parse(end),
    );

void main() {
  final knowledge = ArtKnowledge(
    movements: [movement('impressionism', 'west', 1860, 1890), movement('ukiyo-e', 'japan', 1680, 1868), movement('cubism', 'west', 1907, 1925)],
    links: const [],
    artworks: [
      work('1', 'クロード・モネ', 1872, 'impressionism'),
      work('2', 'クロード・モネ', 1899, 'impressionism'),
      work('3', 'エドガー・ドガ', 1874, 'impressionism'),
      work('4', '葛飾北斎', 1831, 'ukiyo-e'),
      work('5', '歌川広重', 1857, 'ukiyo-e'),
    ],
    artists: const [
      Artist(
        name: 'パブロ・ピカソ',
        nameEn: 'Pablo Picasso',
        shortName: 'ピカソ',
        born: 1881,
        died: 1973,
        region: 'west',
        movementSlugs: ['cubism'],
        summary: '',
        body: '',
        sourceUrl: '',
      ),
    ],
  );

  test('artists come from works and from profiles, in order of activity', () {
    expect(knowledge.artistNames.first, '葛飾北斎');
    expect(knowledge.artistNames, contains('パブロ・ピカソ'));
    expect(knowledge.artistsOf('cubism'), ['パブロ・ピカソ']);
    expect(knowledge.movementsOf('クロード・モネ').map((m) => m.slug), ['impressionism']);
    expect(knowledge.regionOf('歌川広重'), 'japan');
  });

  test('contemporaries overlap in time', () {
    final c = knowledge.contemporaries('クロード・モネ');
    expect(c, contains('エドガー・ドガ'));
    expect(c, isNot(contains('クロード・モネ')));
  });

  test('concurrent movements are in other regions', () {
    final m = knowledge.concurrent(knowledge.movements.first);
    expect(m.map((e) => e.slug), ['ukiyo-e']);
  });

  test('exhibitions are found by the names they use, running first', () {
    final today = DateTime(2026, 10, 27);
    final events = [
      event('モネ展（終了）', '2025-01-01', '2025-03-01'),
      event('これからのモネ展', '2026-12-01', '2027-02-01'),
      event('モネと印象派', '2026-10-01', '2026-11-30'),
      event('北斎展', '2026-10-01', '2026-11-30'),
    ];
    final hits = exhibitionsNaming(events, artistKeys('クロード・モネ', null), today);
    expect(hits.map((e) => e.title), ['モネと印象派', 'これからのモネ展', 'モネ展（終了）']);
    expect(statusOf(events[0], today), ExhibitionStatus.ended);
    expect(statusOf(events[1], today), ExhibitionStatus.upcoming);
    expect(statusOf(events[2], today), ExhibitionStatus.running);
  });

  test('artist keys include the short name and katakana family name', () {
    expect(artistKeys('ピエール＝オーギュスト・ルノワール', null), contains('ルノワール'));
    expect(artistKeys('葛飾北斎', null), ['葛飾北斎']);
    expect(artistKeys('パブロ・ピカソ', knowledge.artist('パブロ・ピカソ')), contains('ピカソ'));
  });

  test('quiz asks about different artists with four choices including the answer', () {
    final quiz = makeQuiz(knowledge, Random(1), count: 10);
    expect(quiz.length, 4); // four artists have works
    expect(quiz.map((q) => q.answer).toSet().length, quiz.length);
    for (final q in quiz) {
      expect(q.choices.length, 4);
      expect(q.choices, contains(q.answer));
      expect(q.choices.toSet().length, 4);
    }
  });
}
