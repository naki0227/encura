import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/art_knowledge.dart';

class KnowledgeRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ArtKnowledge> load() async {
    try {
      final results = await Future.wait([
        _client.from('art_movements').select().order('start_year', ascending: true),
        _client.from('movement_links').select('from_slug, to_slug, kind, note'),
        _client
            .from('artworks')
            .select('id, title, artist, year, movement_slug, collection, image_url, content')
            .order('year', ascending: true),
      ]);
      return ArtKnowledge(
        movements: (results[0] as List).map((e) => Movement.fromJson(e)).toList(),
        links: (results[1] as List).map((e) => MovementLink.fromJson(e)).toList(),
        artworks: (results[2] as List).map((e) => Artwork.fromJson(e)).toList(),
        artists: await _artists(),
      );
    } catch (e) {
      // debugPrint('Error loading art knowledge: $e');
      return ArtKnowledge.empty;
    }
  }

  /// Artist profiles came later than the rest; without them the Learn tab
  /// still works, building artist pages from the artworks alone.
  Future<List<Artist>> _artists() async {
    try {
      final rows = await _client.from('artists').select().order('born', ascending: true);
      return (rows as List).map((e) => Artist.fromJson(e)).toList();
    } catch (e) {
      return const [];
    }
  }
}
