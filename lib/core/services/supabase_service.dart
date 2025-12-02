import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static Future<void> initialize() async {
    final supabaseUrl = dotenv.env['SUPABASE_URL']!;
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> signInAnonymously() async {
    final session = client.auth.currentSession;
    if (session == null) {
      try {
        await client.auth.signInAnonymously();
      } catch (e) {
        // Handle error or log it
        // debugPrint('Error signing in anonymously: $e');
      }
    }
  }
}
