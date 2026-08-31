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
    // Prefer active rows when legacy duplicates have been retired.
    final services = [for (final row in rows) _fromMap(row)]
      ..sort((a, b) => (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0));
    return _deduplicateServices(services);
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
    final normalizedUnit = unit.trim().toUpperCase();
    final root = normalizedUnit == 'KG' ? 'Kiloan' : 'Satuan';
    final rootCategory = await _requireClient()
        .from('service_categories')
        .select('id')
        .eq('shop_id', shopId)
        .eq('name', root)
        .maybeSingle();
    await _requireClient().from('services').insert({
      'shop_id': shopId,
      'category_id': rootCategory?['id'],
      'category_name': category.trim(),
      'item_name': itemName.trim().isEmpty ? name.trim() : itemName.trim(),
      'size_variant': sizeVariant.trim(),
      'material_variant': materialVariant.trim(),
      'unit': normalizedUnit,
      'price': price,
      'estimated_hours': estimatedHours,
      'is_express': isExpress,
    });
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:services:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'services',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    await _requireClient().removeChannel(channel);
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

List<PreviewService> _deduplicateServices(List<PreviewService> services) {
  final unique = <String, PreviewService>{};
  for (final service in services) {
    final key = [
      service.effectiveGroup,
      service.effectiveCategory,
      service.effectiveItem,
      service.effectiveVariant,
      service.unit,
      service.price.toString(),
    ].map((part) => part.trim().toLowerCase()).join('|');
    unique.putIfAbsent(key, () => service);
  }
  return unique.values.toList();
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
