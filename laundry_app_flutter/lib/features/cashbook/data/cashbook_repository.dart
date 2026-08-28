import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class CashbookRepository {
  CashbookRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PreviewCashTransaction>> fetch({required String shopId}) async {
    final rows = await _requireClient()
        .from('cash_transactions')
        .select('id, type, category, description, amount, method, reference_type, reference_id, created_at')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(500);
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> addTransaction({
    required String shopId,
    required String type,
    required String category,
    required String description,
    required int amount,
    required String method,
  }) async {
    await _requireClient().from('cash_transactions').insert({
      'shop_id': shopId,
      'type': type,
      'category': category,
      'description': description.trim(),
      'amount': amount,
      'method': method,
    });
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:cash_transactions:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cash_transactions',
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

PreviewCashTransaction _fromMap(Map<String, dynamic> map) {
  return PreviewCashTransaction(
    id: map['id'] as String,
    referenceId: (map['reference_id'] ?? '') as String,
    referenceType: (map['reference_type'] ?? '') as String,
    type: (map['type'] ?? 'IN') as String,
    category: (map['category'] ?? '') as String,
    description: (map['description'] ?? '') as String,
    amount: (map['amount'] as num? ?? 0).toInt(),
    method: (map['method'] ?? 'Tunai') as String,
    createdAt: DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
  );
}
