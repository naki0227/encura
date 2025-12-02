import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MapService {
  final SupabaseClient _supabase = Supabase.instance.client;
  late final GenerativeModel _model;

  MapService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) {
      throw Exception('GEMINI_API_KEY not found in .env');
    }
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-exp', // Using Flash for speed
      apiKey: apiKey,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );
  }

  Future<bool> verifyAndUploadMap(File imageFile, String? eventId, String? venueId) async {
    try {
      // 1. Verify with Gemini
      final imageBytes = await imageFile.readAsBytes();
      final prompt = TextPart(
          'Is this image a map, floor plan, or venue guide? Respond with JSON: {"is_map": true/false}');
      final imagePart = DataPart('image/jpeg', imageBytes); // Assuming jpeg or converting

      final response = await _model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text == null) return false;

      final jsonResponse = jsonDecode(response.text!) as Map<String, dynamic>;
      final isMap = jsonResponse['is_map'] as bool? ?? false;

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
