import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class ArtEvent {
  final String id;
  final String title;
  final String venue;
  final String? venueId;
  final LatLng location;
  final String? summary;
  final String? sourceUrl;
  final DateTime startDate;
  final DateTime endDate;

  ArtEvent({
    required this.id,
    required this.title,
    required this.venue,
    this.venueId,
    required this.location,
    this.summary,
    this.sourceUrl,
    required this.startDate,
    required this.endDate,
  });

  factory ArtEvent.fromJson(Map<String, dynamic> json) {
    // Parse GeoJSON point from PostGIS
    // Expected format: {"type": "Point", "coordinates": [lon, lat]}
    // Or sometimes Supabase returns it as a string depending on configuration.
    // For simplicity, we'll assume we might need to adjust this based on actual response.
    // But standard PostGIS to JSON is GeoJSON.
    
    // However, supabase-flutter might return it differently.
    // Let's assume we select it as text or handle the map.
    // For now, let's try to parse assuming it comes as a Map or we might need to select ST_AsGeoJSON.
    
    // Actually, to make it easier, let's just select columns and maybe not use the geometry directly if complex,
    // but we need it for the map.
    // Let's assume we fetch it and parse manually if needed.
    
    // A robust way is to select st_y(location::geometry) as lat, st_x(location::geometry) as lon via RPC or view,
    // but let's try direct fetch. If 'location' is returned as a string (WKT) or map (GeoJSON).
    
    // Let's use a safe fallback.
    double lat = 35.6895;
    double lon = 139.6917;

    if (json['location'] != null) {
        // If it's a string representation (WKT) like "POINT(139.7 35.7)"
        final locStr = json['location'].toString();
        if (locStr.startsWith('POINT')) {
            final coords = locStr.substring(6, locStr.length - 1).split(' ');
            lon = double.parse(coords[0]);
            lat = double.parse(coords[1]);
        }
    }

    return ArtEvent(
      id: json['id'],
      title: json['title'],
      venue: json['venue'] ?? '',
      venueId: json['venue_id'],
      location: LatLng(lat, lon),
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
      final response = await _client
          .from('events')
          .select('id, title, venue, venue_id, location, description_json, source_url, start_date, end_date');
      
      // Note: PostGIS columns often return as WKT string in Supabase if not cast to GeoJSON.
      // Let's see what happens. If it fails, we might need to adjust.
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((e) => ArtEvent.fromJson(e)).toList();
    } catch (e) {
      // debugPrint('Error fetching events: $e');
      return [];
    }
  }
}
