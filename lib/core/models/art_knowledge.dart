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

class Artist {
  final String name;
  final String nameEn;
  final String? shortName;
  final int? born;
  final int? died;
  final String region;
  final List<String> movementSlugs;
  final String summary;
  final String body;
  final String sourceUrl;

  const Artist({
    required this.name,
    required this.nameEn,
    required this.shortName,
    required this.born,
    required this.died,
    required this.region,
    required this.movementSlugs,
    required this.summary,
    required this.body,
    required this.sourceUrl,
  });

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        name: json['name'],
        nameEn: json['name_en'] ?? '',
        shortName: json['short_name'],
        born: json['born'],
        died: json['died'],
        region: json['region'] ?? '',
        movementSlugs: [for (final s in (json['movement_slugs'] as List?) ?? const []) s as String],
        summary: json['summary'] ?? '',
        body: json['body'] ?? '',
        sourceUrl: json['source_url'] ?? '',
      );

  /// "1840–1926" / "1881–" / "".
  String get lifeLabel {
    if (born == null && died == null) return '';
    return '${born ?? '?'}–${died ?? ''}';
  }

  String get regionLabel => Movement.regionLabels[region] ?? region;
}

/// Everything the Learn tab shows, loaded once (a few hundred rows at most).
class ArtKnowledge {
  final List<Movement> movements;
  final List<MovementLink> links;
  final List<Artwork> artworks;

  /// Artists with a written profile. Artists who only appear on artworks
  /// still have a page, built from their works.
  final List<Artist> artists;

  ArtKnowledge({required this.movements, required this.links, required this.artworks, this.artists = const []});

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

  Artist? artist(String name) {
    for (final a in artists) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// Every artist the app knows, from profiles and from artworks, in order
  /// of when they were active.
  late final List<String> artistNames = {for (final a in artworks) a.artist, for (final a in artists) a.name}.toList()
    ..sort((a, b) => (activeFrom(a) ?? 99999).compareTo(activeFrom(b) ?? 99999));

  /// The birth year, or the year of the earliest dated work.
  int? activeFrom(String name) {
    final born = artist(name)?.born;
    if (born != null) return born;
    final years = [for (final a in artworks) if (a.artist == name && a.year != null) a.year!];
    return years.isEmpty ? null : years.reduce((a, b) => a < b ? a : b);
  }

  /// The death year, or the year of the latest dated work.
  int? activeTo(String name) {
    final profile = artist(name);
    if (profile != null && (profile.died != null || profile.born != null)) return profile.died;
    final years = [for (final a in artworks) if (a.artist == name && a.year != null) a.year!];
    return years.isEmpty ? null : years.reduce((a, b) => a > b ? a : b);
  }

  /// Where the artist worked: from the profile, else from their works' movements.
  String? regionOf(String name) {
    final profile = artist(name);
    if (profile != null) return profile.region;
    for (final m in movementsOf(name)) {
      return m.region;
    }
    return null;
  }

  /// A picture for the artist: their earliest dated work.
  String coverOfArtist(String name) {
    final works = byArtist(name)..sort((a, b) => (a.year ?? 99999).compareTo(b.year ?? 99999));
    return works.isEmpty ? '' : works.first.imageUrl;
  }

  /// Movements the artist belongs to, in time order.
  List<Movement> movementsOf(String name) {
    final slugs = {
      for (final a in artworks)
        if (a.artist == name && a.movementSlug != null) a.movementSlug!,
      ...?artist(name)?.movementSlugs,
    };
    return movements.where((m) => slugs.contains(m.slug)).toList();
  }

  /// Artists of a movement, in order of when they were active.
  List<String> artistsOf(String slug) =>
      artistNames.where((name) => movementsOf(name).any((m) => m.slug == slug)).toList();

  /// Artists alive or at work at the same time, nearest first.
  List<String> contemporaries(String name, {int limit = 12}) {
    final from = activeFrom(name);
    if (from == null) return const [];
    final to = activeTo(name) ?? from + 60;
    final others = <String, int>{};
    for (final other in artistNames) {
      if (other == name) continue;
      final f = activeFrom(other);
      if (f == null) continue;
      final t = activeTo(other) ?? f + 60;
      if (f <= to && t >= from) others[other] = (f - from).abs();
    }
    final sorted = others.keys.toList()..sort((a, b) => others[a]!.compareTo(others[b]!));
    return sorted.take(limit).toList();
  }

  /// Movements in other regions that overlap this one in time.
  List<Movement> concurrent(Movement movement) {
    final end = movement.endYear ?? DateTime.now().year;
    return movements
        .where((m) =>
            m.region != movement.region && m.startYear <= end && (m.endYear ?? DateTime.now().year) >= movement.startYear)
        .toList();
  }
}
