// Art history as the app teaches it: movements, how they connect, and
// public-domain artworks. All rows are read-only content.

class Movement {
  final String slug;
  final String nameJa;
  final String nameEn;
  final String region;
  final int startYear;
  final int? endYear;
  final String summary;
  final String body;
  final String sourceUrl;

  const Movement({
    required this.slug,
    required this.nameJa,
    required this.nameEn,
    required this.region,
    required this.startYear,
    required this.endYear,
    required this.summary,
    required this.body,
    required this.sourceUrl,
  });

  factory Movement.fromJson(Map<String, dynamic> json) => Movement(
        slug: json['slug'],
        nameJa: json['name_ja'],
        nameEn: json['name_en'],
        region: json['region'],
        startYear: json['start_year'],
        endYear: json['end_year'],
        summary: json['summary'] ?? '',
        body: json['body'] ?? '',
        sourceUrl: json['source_url'] ?? '',
      );

  /// "1860–1890年ごろ" / "1970年ごろ〜".
  String get period => endYear == null ? '$startYear年ごろ〜' : '$startYear–$endYear年ごろ';

  String get regionLabel => regionLabels[region] ?? region;

  static const regionLabels = {'west': '西洋', 'japan': '日本', 'east_asia': '東アジア'};
}

class MovementLink {
  final String fromSlug;
  final String toSlug;
  final String kind;
  final String note;

  const MovementLink({required this.fromSlug, required this.toSlug, required this.kind, required this.note});

  factory MovementLink.fromJson(Map<String, dynamic> json) => MovementLink(
        fromSlug: json['from_slug'],
        toSlug: json['to_slug'],
        kind: json['kind'],
        note: json['note'] ?? '',
      );

  /// How [toSlug] relates to [fromSlug], in a word.
  String get kindLabel => const {'led_to': '受け継ぐ', 'reaction': '反発', 'influence': '影響'}[kind] ?? kind;
}

class Artwork {
  final String id;
  final String title;
  final String artist;
  final int? year;
  final String? movementSlug;
  final String? collection;
  final String imageUrl;
  final String content;

  const Artwork({
    required this.id,
    required this.title,
    required this.artist,
    required this.year,
    required this.movementSlug,
    required this.collection,
    required this.imageUrl,
    required this.content,
  });

  factory Artwork.fromJson(Map<String, dynamic> json) => Artwork(
        id: json['id'],
        title: json['title'],
        artist: json['artist'],
        year: json['year'],
        movementSlug: json['movement_slug'],
        collection: json['collection'],
        imageUrl: json['image_url'] ?? '',
        content: json['content'] ?? '',
      );

  String get yearLabel => year == null ? '' : '$year年';
}

/// Everything the Learn tab shows, loaded once (a few hundred rows at most).
class ArtKnowledge {
  final List<Movement> movements;
  final List<MovementLink> links;
  final List<Artwork> artworks;

  ArtKnowledge({required this.movements, required this.links, required this.artworks});

  static final empty = ArtKnowledge(movements: const [], links: const [], artworks: const []);

  bool get isEmpty => movements.isEmpty && artworks.isEmpty;

  Movement? movement(String? slug) {
    for (final m in movements) {
      if (m.slug == slug) return m;
    }
    return null;
  }

  /// Movements this one came from (links pointing at it).
  List<MovementLink> linksInto(String slug) => links.where((l) => l.toSlug == slug).toList();

  /// Movements that came from this one.
  List<MovementLink> linksOutOf(String slug) => links.where((l) => l.fromSlug == slug).toList();

  /// Works of a movement in time order (undated last).
  List<Artwork> worksOf(String slug) {
    final works = artworks.where((a) => a.movementSlug == slug).toList()
      ..sort((a, b) => (a.year ?? 99999).compareTo(b.year ?? 99999));
    return works;
  }

  List<Artwork> byArtist(String artist, {String? except}) =>
      artworks.where((a) => a.artist == artist && a.id != except).toList();

  /// A picture for the movement: its earliest dated work.
  String coverOf(String slug) {
    final works = worksOf(slug);
    return works.isEmpty ? '' : works.first.imageUrl;
  }
}
