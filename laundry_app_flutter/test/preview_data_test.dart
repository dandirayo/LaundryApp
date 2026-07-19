import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('pembayaran melunasi pesanan dan masuk Buku Kas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final initialState = container.read(previewDataProvider);
    expect(initialState.orders, isEmpty);
    expect(initialState.payments, isEmpty);
    expect(initialState.cashTransactions, isEmpty);

    final initialOrder = notifier.createOrderWithItems(
      customerId: initialState.customers.first.id,
      items: [(serviceId: initialState.services.first.id, quantity: 3)],
      paidAmount: 0,
      paymentMethod: 'QRIS',
      employeeId: initialState.employees.first.id,
      note: '',
    );

    notifier.addPayment(
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

  test('layanan satuan dan sepatu tersedia di master lokal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final services = container.read(previewDataProvider).services;

    expect(
      services.any((service) => service.effectiveGroup == 'Satuan'),
      isTrue,
    );
    expect(
      services.any((service) => service.effectiveGroup == 'Sepatu'),
      isTrue,
    );
  });

  test('master layanan memiliki hierarki dan label tidak digabung slash', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final services = container.read(previewDataProvider).services;
    final groups = services.map((service) => service.effectiveGroup).toSet();

    expect(groups, containsAll(['Kiloan', 'Satuan', 'Sepatu', 'Helm']));
    expect(
      services.where((service) => service.effectiveGroup == 'Satuan'),
      isNotEmpty,
    );
    expect(
      services.any(
        (service) =>
            service.effectiveCategory == 'Alat Tidur' &&
            service.effectiveItem == 'Bedcover' &&
            service.effectiveVariant == 'King Size',
      ),
      isTrue,
    );
    expect(
      services.where(
        (service) =>
            service.name.contains('/') ||
            service.effectiveItem.contains('/') ||
            service.effectiveVariant.contains('/'),
      ),
      isEmpty,
    );
  });

  test('harga mengikuti varian dan unit laporan tidak tercampur', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final state = container.read(previewDataProvider);
    final cuciSetrika = state.services.firstWhere(
      (service) => service.id == 'service-cs-reguler',
    );
    final sepatu = state.services.firstWhere(
      (service) => service.id == 'service-sepatu-reguler',
    );
    final helm = state.services.firstWhere(
      (service) => service.id == 'service-helm-reguler',
    );

    final order = notifier.createOrderWithItems(
      customerId: state.customers.first.id,
      items: [
        (serviceId: cuciSetrika.id, quantity: 5),
        (serviceId: sepatu.id, quantity: 2),
        (serviceId: helm.id, quantity: 1),
      ],
      paidAmount: 0,
      paymentMethod: 'Tunai',
      employeeId: state.employees.first.id,
      note: '',
    );

    expect(order.totalPrice, 5 * 7000 + 2 * 25000 + 1 * 20000);
    expect(order.laundryWeightKg, 5);
    expect(order.quantityForUnit('PAIR'), 2);
    expect(order.quantityForUnit('ITEM'), 1);
    expect(order.totalQuantity, 8);
  });

  test('insentif sepatu dibuat sekali saat pesanan sepatu selesai', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final state = container.read(previewDataProvider);
    final shoeService = state.services.firstWhere(
      (service) => service.effectiveGroup == 'Sepatu',
    );
    final order = notifier.createOrderWithItems(
      customerId: state.customers.first.id,
      items: [(serviceId: shoeService.id, quantity: 2)],
      paidAmount: 0,
      paymentMethod: 'Tunai',
      employeeId: state.employees.first.id,
      note: '',
    );

    notifier.updateOrderStatus(order.id, PreviewOrderStatus.ready);
    notifier.updateOrderStatus(order.id, PreviewOrderStatus.ready);

    final incentives = container
        .read(previewDataProvider)
        .cashTransactions
        .where((entry) => entry.referenceType == 'EMPLOYEE_INCENTIVE')
        .toList();

    expect(incentives, hasLength(1));
    expect(incentives.first.amount, 20000);
    expect(incentives.first.type, 'OUT');
  });

  test('absensi terlambat lebih dari 2 jam tetap tersimpan', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final employee = container.read(previewDataProvider).employees.first;

    notifier.addAttendance(
      employeeId: employee.id,
      employeeName: employee.name,
      isCheckOut: false,
      photoPath: 'camera.jpg',
      now: DateTime(2026, 7, 20, 8, 30),
    );

    final record = container.read(previewDataProvider).attendance.first;
    expect(record.attendanceStatus, PreviewAttendanceStatus.severelyLate);
    expect(record.lateMinutes, 150);
  });
}
