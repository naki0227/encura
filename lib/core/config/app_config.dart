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

  /// Rust image optimizer endpoint. Empty disables optimization.
  static const String imageOptimizerUrl = String.fromEnvironment(
    'IMAGE_OPTIMIZER_URL',
    defaultValue: 'https://encura-993497231174.europe-west1.run.app/process',
  );

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
