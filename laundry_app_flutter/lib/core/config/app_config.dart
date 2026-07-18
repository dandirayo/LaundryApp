import 'package:flutter_riverpod/flutter_riverpod.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.current);

class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.localeName,
    required this.timeZoneName,
  });

  static const current = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    localeName: String.fromEnvironment('APP_LOCALE', defaultValue: 'id_ID'),
    timeZoneName: String.fromEnvironment(
      'APP_TIME_ZONE',
      defaultValue: 'Asia/Jakarta',
    ),
  );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String localeName;
  final String timeZoneName;

  bool get isSupabaseConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;
}
