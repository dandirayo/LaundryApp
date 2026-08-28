import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/order_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(),
);

final orderControllerProvider =
    AsyncNotifierProvider<OrderController, List<PreviewOrder>>(
      OrderController.new,
    );

class OrderController extends AsyncNotifier<List<PreviewOrder>> {
  late OrderRepository _repository;
  RealtimeChannel? _channel;
  bool _refreshQueued = false;

  @override
  Future<List<PreviewOrder>> build() async {
    _repository = ref.watch(orderRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<PreviewOrder> create({
    required String customerId,
    required List<({PreviewService service, double quantity})> items,
    required int paidAmount,
    required String paymentMethod,
    required String employeeId,
    required String note,
  }) async {
    final shopId = _shopId();
    if (shopId != null) {
      final maxHours = items
          .map((item) => item.service.estimatedHours)
          .fold<int>(0, (current, value) => value > current ? value : current);
      final order = await _repository.create(
        shopId: shopId,
        customerId: customerId,
        employeeId: _isUuid(employeeId) ? employeeId : null,
        note: note,
        dueAt: DateTime.now().add(Duration(hours: maxHours)),
        paidAmount: paidAmount,
        paymentMethod: paymentMethod,
        items: [
          for (final item in items)
            OrderCreateItem(
              serviceName: item.service.name,
              category: item.service.category,
              unit: item.service.unit,
              quantity: item.quantity,
              unitPrice: item.service.price,
              subtotal: (item.service.price * item.quantity).round(),
            ),
        ],
      );
      await refresh();
      return order;
    }
    return ref
        .read(previewDataProvider.notifier)
        .createOrderWithItems(
          customerId: customerId,
          items: [
            for (final item in items)
              (serviceId: item.service.id, quantity: item.quantity),
          ],
          paidAmount: paidAmount,
          paymentMethod: paymentMethod,
          employeeId: employeeId,
          note: note,
        );
  }

  Future<void> updateStatus(String orderId, PreviewOrderStatus status) async {
    final shopId = _shopId();
    if (shopId != null) {
      final orders = state.value ?? const [];
      final order = orders.firstWhere((o) => o.id == orderId);
      if (status == PreviewOrderStatus.pickedUp && order.remainingAmount > 0) {
        throw StateError('Pesanan belum lunas. Bayar dulu sebelum diambil.');
      }
      await _repository.updateStatus(
        shopId: shopId,
        orderId: orderId,
        status: status,
      );
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).updateOrderStatus(orderId, status);
    }
  }

  Future<void> updateOrderDetails({
    required String orderId,
    required PreviewOrderStatus status,
    required String employeeId,
    required String note,
  }) async {
    final shopId = _shopId();
    if (shopId != null) {
      final orders = state.value ?? const [];
      final order = orders.firstWhere((o) => o.id == orderId);
      if (status == PreviewOrderStatus.pickedUp && order.remainingAmount > 0) {
        throw StateError('Pesanan belum lunas. Bayar dulu sebelum diambil.');
      }
      await _repository.updateDetails(
        shopId: shopId,
        orderId: orderId,
        status: status,
        employeeId: _isUuid(employeeId) ? employeeId : null,
        note: note,
      );
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).updateOrderDetails(
            orderId: orderId,
            status: status,
            employeeId: employeeId,
            note: note,
          );
    }
  }

  Future<void> delete(String orderId) async {
    final shopId = _shopId();
    if (shopId != null) {
      await _repository.delete(
        shopId: shopId,
        orderId: orderId,
      );
      await refresh();
    } else {
      ref.read(previewDataProvider.notifier).deleteOrder(orderId);
    }
  }

  Future<void> addPayment({
    required String orderId,
    required int amount,
    required String method,
  }) async {
    if (_shopId() != null) {
      await _repository.addPayment(
        orderId: orderId,
        amount: amount,
        method: method,
      );
      await refresh();
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addPayment(orderId: orderId, amount: amount, method: method);
    }
  }

  Future<List<PreviewOrder>> _load({required bool subscribe}) async {
    final shopId = _shopId();
    if (shopId == null) return ref.read(previewDataProvider).orders;
    if (subscribe && _channel == null) {
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    return _repository.fetch(shopId);
  }

  String? _shopId() {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return user.shopId;
  }

  void _queueRefresh() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 150), () async {
        _refreshQueued = false;
        await refresh();
      }),
    );
  }

  void _removeChannel() {
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(_repository.removeChannel(channel));
  }
}

bool _isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
).hasMatch(value);
