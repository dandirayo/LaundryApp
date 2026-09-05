import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class EmployeeRequestRepository {
  EmployeeRequestRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<PreviewEmployeeRequest>> fetchRequests({
    required String shopId,
  }) async {
    final rows = await _requireClient()
        .from('employee_requests')
        .select(_selectColumns)
        .eq('shop_id', shopId)
        .order('created_at', ascending: false);

    return [for (final row in rows) _requestFromMap(row)];
  }

  Future<void> createRequest({
    required String shopId,
    required String employeeId,
    required String employeeName,
    required String type,
    required String reason,
    required int amount,
  }) async {
    await _requireClient().from('employee_requests').insert({
      'shop_id': shopId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'type': type,
      'reason': reason.trim(),
      'amount': amount,
      'status': _statusToStorage(PreviewRequestStatus.pending),
    });
  }

  Future<void> updateRequestStatus({
    required String shopId,
    required String requestId,
    required PreviewRequestStatus status,
    required String reviewNote,
    String paymentMethod = 'Tunai',
  }) async {
    final client = _requireClient();
    final updated = await client
        .from('employee_requests')
        .update({
          'status': _statusToStorage(status),
          'review_note': reviewNote.trim(),
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          if (status == PreviewRequestStatus.paid)
            'payment_method': paymentMethod,
        })
        .eq('id', requestId)
        .eq('shop_id', shopId)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError(
        'Status pengajuan tidak berubah. Muat ulang lalu coba lagi.',
      );
    }
  }

  RealtimeChannel subscribeToRequests({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:employee_requests:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employee_requests',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeSubscription(RealtimeChannel channel) async {
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

PreviewEmployeeRequest _requestFromMap(Map<String, dynamic> map) {
  return PreviewEmployeeRequest(
    id: map['id'] as String,
    employeeId: map['employee_id'] as String? ?? '',
    employeeName: (map['employee_name'] ?? 'Karyawan') as String,
    type: (map['type'] ?? 'Request') as String,
    reason: (map['reason'] ?? '') as String,
    amount: (map['amount'] ?? 0) as int,
    status: _statusFromStorage(map['status'] as String?),
    reviewNote: (map['review_note'] ?? '') as String,
    createdAt:
        DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
  );
}

PreviewRequestStatus _statusFromStorage(String? value) {
  return switch ((value ?? '').toLowerCase()) {
    'approved' => PreviewRequestStatus.approved,
    'rejected' => PreviewRequestStatus.rejected,
    'paid' => PreviewRequestStatus.paid,
    'completed' => PreviewRequestStatus.completed,
    _ => PreviewRequestStatus.pending,
  };
}

String _statusToStorage(PreviewRequestStatus status) {
  return switch (status) {
    PreviewRequestStatus.pending => 'pending',
    PreviewRequestStatus.approved => 'approved',
    PreviewRequestStatus.rejected => 'rejected',
    PreviewRequestStatus.paid => 'paid',
    PreviewRequestStatus.completed => 'completed',
  };
}

const _selectColumns =
    'id, shop_id, employee_id, employee_name, type, reason, amount, status, review_note, created_at, reviewed_at';
