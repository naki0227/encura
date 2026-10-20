import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../models/geo_point.dart';

class ArtEvent {
  final String id;
  final String title;
  final String venue;
  final String? venueId;
  /// Null when the event has no known location.
  final LatLng? location;
  final String? summary;
  final String? sourceUrl;
  final DateTime startDate;
  final DateTime endDate;

  ArtEvent({
    required this.id,
    required this.title,
    required this.venue,
    this.venueId,
    this.location,
    this.summary,
    this.sourceUrl,
    required this.startDate,
    required this.endDate,
  });

  factory ArtEvent.fromJson(Map<String, dynamic> json) {
    return ArtEvent(
      id: json['id'],
      title: json['title'],
      venue: json['venue'] ?? '',
      venueId: json['venue_id'],
      location: parseGeoPoint(json['location']),
      summary: json['description_json']?['summary'],
      sourceUrl: json['source_url'],
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : DateTime.now(),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : DateTime.now(),
    );
  }
}

class EventService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<ArtEvent>> getEvents() async {
    try {
      // We need to cast location to text to parse it easily in Dart
      final now = DateTime.now();
      final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final response = await _client
          .from('events')
          .select('id, title, venue, venue_id, location, description_json, source_url, start_date, end_date')
          .gte('end_date', today)
          .order('start_date', ascending: true);
      
      // Note: PostGIS columns often return as WKT string in Supabase if not cast to GeoJSON.
      // Let's see what happens. If it fails, we might need to adjust.
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => ArtEvent.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching events: $e');
      return [];
    }
  }

  Future<List<ArtEvent>> getEventsByVenue(String venueId) async {
    try {
      final now = DateTime.now();
      final today = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final response = await _client
          .from('events')
          .select('id, title, venue, venue_id, location, description_json, source_url, start_date, end_date')
          .eq('venue_id', venueId)
          .gte('end_date', today)
          .order('start_date', ascending: true);
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => ArtEvent.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching events by venue: $e');
      return [];
    }
  }
}
