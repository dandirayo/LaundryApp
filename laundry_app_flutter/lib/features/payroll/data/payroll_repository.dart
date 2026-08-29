import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';

class PayrollPayment {
  const PayrollPayment({
    required this.id,
    required this.employeeId,
    required this.periodStart,
    required this.periodEnd,
    required this.amount,
    required this.method,
    required this.paidAt,
    required this.note,
  });

  final String id;
  final String employeeId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int amount;
  final String method;
  final DateTime paidAt;
  final String note;
}

class PayrollRepository {
  PayrollRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PayrollPayment>> fetch({required String shopId}) async {
    final rows = await _requireClient()
        .from('payroll_payments')
        .select(
          'id, employee_id, period_start, period_end, amount, method, paid_at, note',
        )
        .eq('shop_id', shopId)
        .order('paid_at', ascending: false)
        .limit(200);
    return [for (final row in rows) _fromMap(row)];
  }

  Future<bool> isSalaryPaid({
    required String shopId,
    required String employeeId,
    required DateTime periodStart,
  }) async {
    final rows = await _requireClient()
        .from('payroll_payments')
        .select('id')
        .eq('shop_id', shopId)
        .eq('employee_id', employeeId)
        .eq('period_start', _dateString(periodStart))
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> paySalary({
    required String shopId,
    required String employeeId,
    required int amount,
    required String method,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? paidBy,
    String note = '',
  }) async {
    await _requireClient().from('payroll_payments').insert({
      'shop_id': shopId,
      'employee_id': employeeId,
      'amount': amount,
      'method': method,
      'period_start': _dateString(periodStart),
      'period_end': _dateString(periodEnd),
      'paid_by': ?paidBy,
      'note': note.trim(),
    });
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:payroll_payments:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payroll_payments',
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

  String _dateString(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

PayrollPayment _fromMap(Map<String, dynamic> map) {
  return PayrollPayment(
    id: map['id'] as String,
    employeeId: (map['employee_id'] ?? '') as String,
    periodStart:
        DateTime.tryParse((map['period_start'] ?? '') as String) ??
        DateTime.now(),
    periodEnd:
        DateTime.tryParse((map['period_end'] ?? '') as String) ??
        DateTime.now(),
    amount: (map['amount'] as num? ?? 0).toInt(),
    method: (map['method'] ?? 'Tunai') as String,
    paidAt:
        DateTime.tryParse((map['paid_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
    note: (map['note'] ?? '') as String,
  );
}
