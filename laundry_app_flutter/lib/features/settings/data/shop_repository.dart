import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';

class ShopSettings {
  const ShopSettings({
    required this.name,
    required this.phone,
    required this.address,
  });

  final String name;
  final String phone;
  final String address;
}

class ShopRepository {
  ShopRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<ShopSettings> fetch(String shopId) async {
    final row = await _requireClient()
        .from('shops')
        .select('name, phone, address')
        .eq('id', shopId)
        .single();
    return ShopSettings(
      name: (row['name'] ?? '') as String,
      phone: (row['phone'] ?? '') as String,
      address: (row['address'] ?? '') as String,
    );
  }

  Future<void> update({
    required String shopId,
    required String name,
    required String phone,
    required String address,
  }) async {
    await _requireClient()
        .from('shops')
        .update({
          'name': name.trim(),
          'phone': phone.trim(),
          'address': address.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', shopId);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const Failure(
        code: 'supabase-not-configured',
        message: 'Supabase belum dikonfigurasi.',
      );
    }
    return client;
  }
}
