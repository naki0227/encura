/// Build-time configuration.
///
/// Values come from `--dart-define` / `--dart-define-from-file` at build time
/// (see docs/RELEASE.md). Nothing secret belongs here: the Supabase anon key
/// is a public client key protected by RLS, and the Gemini API key lives only
/// in the `curator` Edge Function's secrets.
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Amazon Associates tracking ID (e.g. "encura-22"). Public by nature:
  /// it appears in every link. Empty hides the art book links.
  static const String amazonAssociateTag = String.fromEnvironment('AMAZON_ASSOCIATE_TAG');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
