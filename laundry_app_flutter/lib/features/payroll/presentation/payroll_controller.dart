import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/payroll_repository.dart';

final payrollRepositoryProvider = Provider<PayrollRepository>(
  (ref) => PayrollRepository(),
);

final payrollControllerProvider =
    AsyncNotifierProvider<PayrollController, PayrollState>(
      PayrollController.new,
    );

class PayrollState {
  const PayrollState({
    required this.payments,
    required this.isOnline,
  });

  final List<PayrollPayment> payments;
  final bool isOnline;

  bool isSalaryPaid(String employeeId, DateTime periodStart) {
    final periodDate = DateTime(periodStart.year, periodStart.month, periodStart.day);
    return payments.any((p) =>
      p.employeeId == employeeId &&
      p.periodStart.year == periodDate.year &&
      p.periodStart.month == periodDate.month &&
      p.periodStart.day == periodDate.day
    );
  }
}

class PayrollController extends AsyncNotifier<PayrollState> {
  late PayrollRepository _repository;
  RealtimeChannel? _channel;
  bool _refreshQueued = false;

  @override
  Future<PayrollState> build() async {
    _repository = ref.watch(payrollRepositoryProvider);
    ref.onDispose(_removeChannel);
    return _load(subscribe: true);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _load(subscribe: false));
  }

  Future<void> paySalary({
    required String employeeId,
    required int amount,
    required String method,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final shopId = _onlineShopId();
    if (shopId != null) {
      final user = ref.read(authControllerProvider).value?.user;
      await _repository.paySalary(
        shopId: shopId,
        employeeId: employeeId,
        amount: amount,
        method: method,
        periodStart: periodStart,
        periodEnd: periodEnd,
        paidBy: user?.userId,
      );
    } else {
      ref.read(previewDataProvider.notifier).payWeeklySalary(
        employeeId: employeeId,
        method: method,
      );
    }
    await refresh();
  }

  Future<PayrollState> _load({required bool subscribe}) async {
    final shopId = _onlineShopId();
    if (shopId == null) {
      // In preview mode, derive payroll state from cash transactions
      final data = ref.read(previewDataProvider);
      final payrollTransactions = data.cashTransactions
          .where((t) => t.referenceType == 'PAYROLL')
          .toList();
      return PayrollState(
        payments: [
          for (final t in payrollTransactions)
            PayrollPayment(
              id: t.id,
              employeeId: _extractEmployeeId(t.referenceId),
              periodStart: _extractPeriodStart(t.referenceId),
              periodEnd: _extractPeriodStart(t.referenceId).add(const Duration(days: 6)),
              amount: t.amount,
              method: t.method,
              paidAt: t.createdAt,
              note: '',
            ),
        ],
        isOnline: false,
      );
    }
    if (subscribe && _channel == null) {
      _channel = _repository.subscribe(
        shopId: shopId,
        onChanged: _queueRefresh,
      );
    }
    final payments = await _repository.fetch(shopId: shopId);
    return PayrollState(
      payments: payments,
      isOnline: true,
    );
  }

  String? _onlineShopId() {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return null;
    }
    return user.shopId;
  }

  // Extract employee ID from reference like 'PAYROLL-employeeId-20260828'
  String _extractEmployeeId(String referenceId) {
    final parts = referenceId.split('-');
    if (parts.length >= 2) return parts[1];
    return '';
  }

  // Extract period start date from reference like 'PAYROLL-employeeId-20260828'
  DateTime _extractPeriodStart(String referenceId) {
    final parts = referenceId.split('-');
    if (parts.length >= 3) {
      final dateStr = parts.last;
      if (dateStr.length == 8) {
        return DateTime.tryParse(
          '${dateStr.substring(0, 4)}-${dateStr.substring(4, 6)}-${dateStr.substring(6, 8)}'
        ) ?? DateTime.now();
      }
    }
    return DateTime.now();
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
