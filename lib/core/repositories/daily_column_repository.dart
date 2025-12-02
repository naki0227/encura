import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_column.dart';

class DailyColumnRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<DailyColumn?> getTodayColumn() async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Fetch from remote Supabase DB
      final response = await _client
          .from('daily_columns')
          .select()
          .eq('display_date', todayStr)
          .maybeSingle();

      if (response == null) {
        // Fallback: Fetch the latest column if today's is missing
        final latestResponse = await _client
            .from('daily_columns')
            .select()
            .order('display_date', ascending: false)
            .limit(1)
            .maybeSingle();
            
        if (latestResponse != null) {
          return DailyColumn.fromJson(latestResponse);
        }
        return null;
      }

      return DailyColumn.fromJson(response);
    } catch (e) {
      // debugPrint('Error fetching daily column: $e');
      return null;
    }
  }
  Future<List<DailyColumn>> searchColumns({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      var queryBuilder = _client
          .from('daily_columns')
          .select()
          .lte('display_date', todayStr);

      if (query != null && query.isNotEmpty) {
        queryBuilder = queryBuilder.or('title.ilike.%$query%,content.ilike.%$query%,artist.ilike.%$query%');
      }

      final response = await queryBuilder
          .order('display_date', ascending: false)
          .range(offset, offset + limit - 1);
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => DailyColumn.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error searching columns: $e');
      return [];
    }
  }
}
