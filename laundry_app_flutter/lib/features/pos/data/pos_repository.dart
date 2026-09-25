import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../domain/pos_models.dart';

class PosRepository {
  PosRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<PosProduct>> fetchProducts(String businessId) async {
    final rows = await _requireClient()
        .from('pos_products')
        .select('id, business_id, name, category, price, is_active')
        .eq('business_id', businessId)
        .order('sort_order')
        .order('name');
    return [for (final row in rows) PosProduct.fromMap(row)];
  }

  Future<List<PosSale>> fetchTodaySales(String businessId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final rows = await _requireClient()
        .from('pos_sales')
        .select(
          'id, business_id, sale_number, total, payment_method, created_at',
        )
        .eq('business_id', businessId)
        .gte('created_at', start.toUtc().toIso8601String())
        .order('created_at', ascending: false);
    return [for (final row in rows) PosSale.fromMap(row)];
  }

  Future<bool> fetchTodayOpen(String businessId) async {
    final row = await _requireClient()
        .from('business_daily_operations')
        .select('is_open')
        .eq('business_id', businessId)
        .eq('operation_date', _dateKey(DateTime.now()))
        .maybeSingle();
    return row?['is_open'] as bool? ?? false;
  }

  Future<void> setTodayOpen({
    required String businessId,
    required String profileId,
    required bool isOpen,
  }) async {
    final operationDate = _dateKey(DateTime.now());
    final existing = await _requireClient()
        .from('business_daily_operations')
        .select('id')
        .eq('business_id', businessId)
        .eq('operation_date', operationDate)
        .maybeSingle();
    if (existing == null) {
      await _requireClient().from('business_daily_operations').insert({
        'business_id': businessId,
        'operation_date': operationDate,
        'is_open': isOpen,
        'updated_by': profileId,
      });
      return;
    }
    await _requireClient()
        .from('business_daily_operations')
        .update({'is_open': isOpen, 'updated_by': profileId})
        .eq('id', existing['id'] as String);
  }

  Future<PosProduct> saveProduct({
    required String businessId,
    String? id,
    required String name,
    required String category,
    required int price,
    required bool isActive,
  }) async {
    final values = {
      'business_id': businessId,
      'name': name.trim(),
      'category': category.trim(),
      'price': price,
      'is_active': isActive,
    };
    final query = id == null
        ? _requireClient().from('pos_products').insert(values)
        : _requireClient().from('pos_products').update(values).eq('id', id);
    final row = await query
        .select('id, business_id, name, category, price, is_active')
        .single();
    return PosProduct.fromMap(row);
  }

  Future<String> createSale({
    required String businessId,
    required String paymentMethod,
    required String notes,
    required Map<String, int> quantities,
  }) async {
    final result = await _requireClient().rpc(
      'create_pos_sale',
      params: {
        'p_business_id': businessId,
        'p_payment_method': paymentMethod,
        'p_notes': notes.trim(),
        'p_items': [
          for (final entry in quantities.entries)
            {'product_id': entry.key, 'quantity': entry.value},
        ],
      },
    );
    return result as String;
  }

  SupabaseClient _requireClient() => _client!;

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
