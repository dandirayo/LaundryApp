import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

class SupabaseService {
  const SupabaseService._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize(AppConfig config) async {
    if (!config.isSupabaseConfigured || _initialized) {
      return;
    }

    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient? get maybeClient {
    if (!_initialized) {
      return null;
    }
    return Supabase.instance.client;
  }
}
