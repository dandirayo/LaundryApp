import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class ExpenseRepository {
  ExpenseRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PreviewExpense>> fetch({required String shopId}) async {
    final rows = await _requireClient()
        .from('expenses')
        .select('id, description, category, amount, method, created_at')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> add({
    required String shopId,
    required String description,
    required String category,
    required int amount,
    required String method,
    String? createdBy,
  }) async {
    await _requireClient().from('expenses').insert({
      'shop_id': shopId,
      'description': description.trim(),
      'category': category,
      'amount': amount,
      'method': method,
      if (createdBy != null) 'created_by': createdBy,
    });
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:expenses:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
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

PreviewExpense _fromMap(Map<String, dynamic> map) {
  return PreviewExpense(
    id: map['id'] as String,
    description: (map['description'] ?? '') as String,
    category: (map['category'] ?? 'Operasional') as String,
    amount: (map['amount'] as num? ?? 0).toInt(),
    method: (map['method'] ?? 'Tunai') as String,
    createdAt: DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ?? DateTime.now(),
  );
}
