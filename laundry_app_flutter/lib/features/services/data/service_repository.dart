import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class ServiceRepository {
  ServiceRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PreviewService>> fetch(String shopId) async {
    final rows = await _requireClient()
        .from('services')
        .select(
          'id, category_name, item_name, size_variant, material_variant, unit, price, estimated_hours, is_express, is_active, sort_order',
        )
        .eq('shop_id', shopId)
        .order('sort_order')
        .order('item_name');
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> add({
    required String shopId,
    required String name,
    required String itemName,
    required String sizeVariant,
    required String materialVariant,
    required String category,
    required String unit,
    required int price,
    required int estimatedHours,
    required bool isExpress,
  }) async {
    await _requireClient().from('services').insert({
      'shop_id': shopId,
      'category_name': category,
      'item_name': itemName.trim().isEmpty ? name.trim() : itemName.trim(),
      'size_variant': sizeVariant.trim(),
      'material_variant': materialVariant.trim(),
      'unit': unit,
      'price': price,
      'estimated_hours': estimatedHours,
      'is_express': isExpress,
    });
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

PreviewService _fromMap(Map<String, dynamic> map) {
  final itemName = (map['item_name'] ?? 'Layanan') as String;
  final size = (map['size_variant'] ?? '') as String;
  final material = (map['material_variant'] ?? '') as String;
  final variants = [
    size,
    material,
  ].where((value) => value.isNotEmpty).join(' ');
  return PreviewService(
    id: map['id'] as String,
    name: variants.isEmpty ? itemName : '$itemName $variants',
    category: (map['category_name'] ?? '') as String,
    unit: (map['unit'] ?? 'PCS') as String,
    price: (map['price'] as num? ?? 0).toInt(),
    estimatedHours: (map['estimated_hours'] as num? ?? 0).toInt(),
    isExpress: (map['is_express'] ?? false) as bool,
    isActive: (map['is_active'] ?? true) as bool,
    categoryName: (map['category_name'] ?? '') as String,
    itemName: itemName,
    variantName: variants,
    sortOrder: (map['sort_order'] as num? ?? 0).toInt(),
  );
}
