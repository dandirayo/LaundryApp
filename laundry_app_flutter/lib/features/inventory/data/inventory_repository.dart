import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class InventoryRepository {
  InventoryRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<
    ({
      List<PreviewInventoryItem> items,
      List<PreviewInventoryMovement> movements,
    })
  >
  fetch({required String shopId}) async {
    final results = await Future.wait([
      _requireClient()
          .from('inventory_items')
          .select(
            'id, name, stock, unit, min_stock, purchase_price, note, is_active',
          )
          .eq('shop_id', shopId)
          .order('name'),
      _requireClient()
          .from('inventory_movements')
          .select('id, item_id, item_name, type, quantity, note, created_at')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false)
          .limit(50),
    ]);
    return (
      items: [for (final row in results[0]) _itemFromMap(row)],
      movements: [for (final row in results[1]) _movementFromMap(row)],
    );
  }

  Future<void> addItem({
    required String shopId,
    required String name,
    required double stock,
    required String unit,
    required double minStock,
    required int purchasePrice,
    required String note,
  }) async {
    await _requireClient().from('inventory_items').insert({
      'shop_id': shopId,
      'name': name.trim(),
      'stock': stock,
      'unit': unit.trim(),
      'min_stock': minStock,
      'purchase_price': purchasePrice,
      'note': note.trim(),
    });
  }

  Future<void> adjust({
    required String itemId,
    required double quantity,
    required String type,
    required String note,
  }) async {
    await _requireClient().rpc(
      'adjust_inventory_stock',
      params: {
        'p_item_id': itemId,
        'p_quantity': quantity,
        'p_type': type,
        'p_note': note.trim(),
      },
    );
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:inventory:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_movements',
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

PreviewInventoryItem _itemFromMap(Map<String, dynamic> map) {
  return PreviewInventoryItem(
    id: map['id'] as String,
    name: (map['name'] ?? '') as String,
    stock: (map['stock'] as num? ?? 0).toDouble(),
    unit: (map['unit'] ?? 'pcs') as String,
    minStock: (map['min_stock'] as num? ?? 0).toDouble(),
    purchasePrice: (map['purchase_price'] as num? ?? 0).toInt(),
    note: (map['note'] ?? '') as String,
    isActive: (map['is_active'] ?? true) as bool,
  );
}

PreviewInventoryMovement _movementFromMap(Map<String, dynamic> map) {
  return PreviewInventoryMovement(
    id: map['id'] as String,
    itemId: map['item_id'] as String,
    itemName: (map['item_name'] ?? '') as String,
    type: (map['type'] ?? '') as String,
    quantity: (map['quantity'] as num? ?? 0).toDouble(),
    note: (map['note'] ?? '') as String,
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
  );
}
