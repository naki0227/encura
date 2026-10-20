import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  static Future<void> initialize() async {
    if (!AppConfig.isSupabaseConfigured) {
      throw StateError(
        'SUPABASE_URL / SUPABASE_ANON_KEY are not set. '
        'Build with --dart-define-from-file=config/prod.json (see docs/RELEASE.md).',
      );
    }

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> signInAnonymously() async {
    final session = client.auth.currentSession;
    if (session == null) {
      try {
        await client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('Error signing in anonymously: $e');
      }
    }
  }
}
