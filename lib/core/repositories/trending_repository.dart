import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trending_article.dart';

class TrendingRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<TrendingArticle>> getTrendingArticles() async {
    try {
      // Fetch articles where is_published is true
      // Note: The user mentioned 'is_published' column in the request, 
      // but schema.sql didn't show it explicitly in the CREATE TABLE statement earlier.
      // However, the user said "Supabaseに trending_articles のデータを投入しました" and "is_published が true の記事を取得".
      // I will assume the column exists.
      final response = await _client
          .from('trending_articles')
          .select()
          .eq('is_published', true)
          .order('published_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => TrendingArticle.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching trending articles: $e');
      return [];
    }
  }
}
