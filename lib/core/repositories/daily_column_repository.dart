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
}
