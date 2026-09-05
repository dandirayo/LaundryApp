import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class OrderRepository {
  OrderRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<PreviewOrder> create({
    required String shopId,
    required String customerId,
    required String? employeeId,
    required String note,
    required DateTime dueAt,
    required int paidAmount,
    required String paymentMethod,
    required List<OrderCreateItem> items,
  }) async {
    if (items.any(
      (item) => !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(item.serviceId),
    )) {
      throw const Failure(
        code: 'service-not-synced',
        message:
            'Layanan belum sinkron. Buka ulang form pesanan dan pilih layanan kembali.',
      );
    }
    late final dynamic response;
    try {
      response = await _requireClient().rpc(
        'create_laundry_order',
        params: {
          'p_customer_id': customerId,
          'p_assigned_employee_id': employeeId,
          'p_note': note.trim(),
          'p_due_at': dueAt.toUtc().toIso8601String(),
          'p_paid_amount': paidAmount,
          'p_payment_method': paymentMethod,
          'p_items': [for (final item in items) item.toMap()],
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == '23502' &&
          error.message.contains('customer_phone_snapshot')) {
        throw const Failure(
          code: 'order-customer-phone-snapshot',
          message:
              'Data pelanggan belum siap digunakan. Tutup lalu buka aplikasi, kemudian coba lagi.',
        );
      }
      throw Failure(
        code: error.code ?? 'order-create-failed',
        message: 'Pesanan belum dapat disimpan. Periksa data lalu coba lagi.',
        details: error,
      );
    }
    final rows = response as List;
    final orderId = (rows.first as Map)['order_id'] as String;
    final orders = await fetch(shopId);
    return orders.firstWhere((order) => order.id == orderId);
  }

  Future<List<PreviewOrder>> fetch(String shopId) async {
    final rows = await _requireClient()
        .from('orders')
        .select(
          'id, order_number, customer_id, customer_name_snapshot, customer_phone_snapshot, total_price, paid_amount, order_status, payment_status, created_at, due_at, assigned_employee_id, received_by_name_snapshot, note, order_items(id, service_id, service_name_snapshot, unit, quantity, unit_price, subtotal)',
        )
        .eq('shop_id', shopId)
        .isFilter('deleted_at', null)
        .order('created_at', ascending: false);
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> updateStatus({
    required String shopId,
    required String orderId,
    required PreviewOrderStatus status,
  }) async {
    await _requireClient()
        .from('orders')
        .update({
          'order_status': _statusToStorage(status),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('shop_id', shopId);
  }

  Future<void> updateDetails({
    required String shopId,
    required String orderId,
    required PreviewOrderStatus status,
    required String? employeeId,
    required String note,
  }) async {
    await _requireClient()
        .from('orders')
        .update({
          'order_status': _statusToStorage(status),
          'assigned_employee_id': employeeId,
          'note': note.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId)
        .eq('shop_id', shopId);
  }

  Future<void> delete({required String shopId, required String orderId}) async {
    await _requireClient()
        .from('orders')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', orderId)
        .eq('shop_id', shopId);
  }

  Future<void> addPayment({
    required String orderId,
    required int amount,
    required String method,
  }) async {
    await _requireClient().rpc(
      'record_order_payment',
      params: {'p_order_id': orderId, 'p_amount': amount, 'p_method': method},
    );
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:orders:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
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
          table: 'order_items',
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
          table: 'payments',
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

class OrderCreateItem {
  const OrderCreateItem({
    required this.serviceId,
    required this.serviceName,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String serviceId;
  final String serviceName;
  final String category;
  final String unit;
  final double quantity;
  final int unitPrice;
  final int subtotal;

  Map<String, dynamic> toMap() => {
    'service_id': serviceId,
    'service_name': serviceName,
    'category': category,
    'unit': unit,
    'quantity': quantity,
    'unit_price': unitPrice,
    'subtotal': subtotal,
  };
}

PreviewOrder _fromMap(Map<String, dynamic> map) {
  final itemRows = (map['order_items'] as List? ?? const []);
  return PreviewOrder(
    id: map['id'] as String,
    orderNumber: (map['order_number'] ?? '') as String,
    customerId: (map['customer_id'] ?? '') as String,
    customerNameSnapshot: (map['customer_name_snapshot'] ?? '') as String,
    customerPhoneSnapshot: (map['customer_phone_snapshot'] ?? '') as String,
    items: [
      for (final raw in itemRows)
        PreviewOrderItem(
          id: raw['id'] as String,
          serviceId: (raw['service_id'] ?? '') as String,
          serviceNameSnapshot: (raw['service_name_snapshot'] ?? '') as String,
          unit: (raw['unit'] ?? 'PCS') as String,
          quantity: (raw['quantity'] as num? ?? 0).toDouble(),
          price: (raw['unit_price'] as num? ?? 0).toInt(),
          total: (raw['subtotal'] as num? ?? 0).toInt(),
        ),
    ],
    totalPrice: (map['total_price'] as num? ?? 0).toInt(),
    paidAmount: (map['paid_amount'] as num? ?? 0).toInt(),
    orderStatus: _statusFromStorage(map['order_status'] as String?),
    paymentStatus: _paymentFromStorage(map['payment_status'] as String?),
    receivedAt:
        DateTime.tryParse((map['created_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
    dueAt:
        DateTime.tryParse((map['due_at'] ?? '') as String)?.toLocal() ??
        DateTime.now(),
    assignedEmployeeId: (map['assigned_employee_id'] ?? '') as String,
    receivedByName: (map['received_by_name_snapshot'] ?? '') as String,
    note: (map['note'] ?? '') as String,
  );
}

PreviewOrderStatus _statusFromStorage(String? value) {
  return switch ((value ?? '').toLowerCase()) {
    'processing' ||
    'washing' ||
    'drying' ||
    'ironing' => PreviewOrderStatus.processing,
    'ready' => PreviewOrderStatus.ready,
    'picked_up' || 'completed' => PreviewOrderStatus.pickedUp,
    'cancelled' => PreviewOrderStatus.cancelled,
    _ => PreviewOrderStatus.received,
  };
}

String _statusToStorage(PreviewOrderStatus status) {
  return switch (status) {
    PreviewOrderStatus.received => 'received',
    PreviewOrderStatus.processing => 'processing',
    PreviewOrderStatus.ready => 'ready',
    PreviewOrderStatus.pickedUp => 'picked_up',
    PreviewOrderStatus.cancelled => 'cancelled',
  };
}

PreviewPaymentStatus _paymentFromStorage(String? value) {
  return switch ((value ?? '').toLowerCase()) {
    'paid' => PreviewPaymentStatus.paid,
    'partial' => PreviewPaymentStatus.partiallyPaid,
    _ => PreviewPaymentStatus.unpaid,
  };
}
