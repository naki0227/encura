import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/event_service.dart'; // Import ArtEvent definition

class EventRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ArtEvent>> getEvents() async {
    try {
      final today = DateTime.now().toIso8601String();
      final response = await _client
          .from('events')
          .select('id, title, venue, location, description_json, source_url, start_date, end_date')
          .gte('end_date', today)
          .order('start_date', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => ArtEvent.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching events: $e');
      return [];
    }
  }
}
