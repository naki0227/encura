import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trending_article.dart';

class TrendingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<TrendingArticle>> getTrendingArticles({int limit = 10}) async {
    try {
      // Fetch articles where is_published is true
      final response = await _client
          .from('trending_articles')
          .select()
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => TrendingArticle.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching trending articles: $e');
      return [];
    }
  }
  Future<List<TrendingArticle>> searchArticles({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var queryBuilder = _client
          .from('trending_articles')
          .select()
          .eq('is_published', true);

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title.ilike.%$query%,content.ilike.%$query%,keyword.ilike.%$query%');
      }

      final response = await queryBuilder
          .order('published_at', ascending: false)
          .range(offset, offset + limit - 1);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => TrendingArticle.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error searching articles: $e');
      return [];
    }
  }
}
