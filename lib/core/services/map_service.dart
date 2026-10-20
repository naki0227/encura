import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MapService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> verifyAndUploadMap(File imageFile, String? eventId, String? venueId) async {
    try {
      // 1. Verify with Gemini (via the curator Edge Function)
      final imageBytes = await imageFile.readAsBytes();
      final response = await _supabase.functions.invoke(
        'curator',
        body: {'task': 'is_map', 'image': base64Encode(imageBytes)},
      );
      final data = response.data;
      final isMap = data is Map && data['is_map'] == true;

      if (!isMap) {
        debugPrint('Image rejected by AI: Not a map.');
        return false;
      }

      // 2. Upload to Supabase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      // Use venue_id if available for path, otherwise event_id
      final path = '${venueId ?? eventId}/$fileName';

      await _supabase.storage.from('venue_maps').upload(
            path,
            imageFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = _supabase.storage.from('venue_maps').getPublicUrl(path);

      // 3. Insert into venue_maps table
      await _supabase.from('venue_maps').insert({
        'event_id': eventId, // Can be null if we are strictly using venue_id now, but keeping for backward compat if needed
        'venue_id': venueId,
        'image_url': imageUrl,
        'is_verified': true,
      });

      return true;
    } catch (e) {
      debugPrint('Error in verifyAndUploadMap: $e');
      return false;
    }
  }

  Future<List<String>> getMaps(String? eventId, String? venueId) async {
    try {
      var query = _supabase
          .from('venue_maps')
          .select('image_url')
          .eq('is_verified', true);
      
      if (venueId != null) {
        query = query.eq('venue_id', venueId);
      } else if (eventId != null) {
        query = query.eq('event_id', eventId);
      } else {
        return [];
      }

      final response = await query.order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((e) => e['image_url'] as String).toList();
    } catch (e) {
      debugPrint('Error fetching maps: $e');
      return [];
    }
  }
}
