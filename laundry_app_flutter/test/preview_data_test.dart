import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('pembayaran melunasi pesanan dan masuk Buku Kas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initialOrder = container.read(previewDataProvider).orders.first;

    container
        .read(previewDataProvider.notifier)
        .addPayment(
          orderId: initialOrder.id,
          amount: initialOrder.remainingAmount,
          method: 'QRIS',
        );

    final state = container.read(previewDataProvider);
    final updatedOrder = state.orders.firstWhere(
      (order) => order.id == initialOrder.id,
    );

    expect(updatedOrder.remainingAmount, 0);
    expect(updatedOrder.paymentStatus, PreviewPaymentStatus.paid);
    expect(state.cashTransactions.first.referenceType, 'PAYMENT');
    expect(state.cashTransactions.first.type, 'IN');
  });

  test('request berbayar idempotent saat masuk Buku Kas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    notifier.addRequest(
      type: 'Request Kasbon',
      reason: 'Kasbon transport',
      amount: 50000,
    );
    final request = container.read(previewDataProvider).requests.first;

    notifier.reviewRequest(request.id, PreviewRequestStatus.approved);
    notifier.payEmployeeRequest(requestId: request.id, method: 'Tunai');

    final state = container.read(previewDataProvider);
    final updatedRequest = state.requests.firstWhere(
      (entry) => entry.id == request.id,
    );

    expect(updatedRequest.status, PreviewRequestStatus.paid);
    expect(state.cashTransactions.first.referenceType, 'EMPLOYEE_REQUEST');
    expect(state.cashTransactions.first.category, 'Kasbon');
    expect(
      () => notifier.payEmployeeRequest(requestId: request.id, method: 'Tunai'),
      throwsA(isA<StateError>()),
    );
  });

  test('pembayaran gaji mingguan tidak bisa dicatat dua kali', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final employee = container.read(previewDataProvider).employees.first;

    notifier.payWeeklySalary(employeeId: employee.id, method: 'Transfer');

    final state = container.read(previewDataProvider);
    expect(state.cashTransactions.first.referenceType, 'PAYROLL');
    expect(state.cashTransactions.first.amount, state.weeklySalaryAmount);
    expect(
      () =>
          notifier.payWeeklySalary(employeeId: employee.id, method: 'Transfer'),
      throwsA(isA<StateError>()),
    );
  });
}
