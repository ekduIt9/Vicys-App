abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get hasCloudConfiguration =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
