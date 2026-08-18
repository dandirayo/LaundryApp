import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class NotificationRepository {
  NotificationRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PreviewNotification>> fetch(String shopId) async {
    final rows = await _requireClient()
        .from('notifications')
        .select('id, title, message, type, action_route, is_read, created_at')
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> markRead(String id) async {
    await _requireClient()
        .from('notifications')
        .update({
          'is_read': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  Future<void> markAllRead(String shopId) async {
    await _requireClient()
        .from('notifications')
        .update({
          'is_read': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('shop_id', shopId)
        .eq('is_read', false);
  }

  Future<void> delete(String id) async {
    await _requireClient().from('notifications').delete().eq('id', id);
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:notifications:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
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

PreviewNotification _fromMap(Map<String, dynamic> map) {
  return PreviewNotification(
    id: map['id'] as String,
    title: (map['title'] ?? '') as String,
    message: (map['message'] ?? '') as String,
    type: (map['type'] ?? 'INFO') as String,
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
    isRead: (map['is_read'] ?? false) as bool,
    actionRoute: (map['action_route'] ?? '') as String,
  );
}
