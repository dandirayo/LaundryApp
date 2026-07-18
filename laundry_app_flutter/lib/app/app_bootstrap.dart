import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../core/config/app_config.dart';
import '../core/services/supabase_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    Intl.defaultLocale = AppConfig.current.localeName;
    await initializeDateFormatting(AppConfig.current.localeName);
    await SupabaseService.initialize(AppConfig.current);
  }
}
