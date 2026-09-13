import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/customers/domain/customer.dart';
import 'package:laundry_app_flutter/features/orders/presentation/order_whatsapp.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('nomor customer boleh kosong dan dinormalisasi menjadi null', () {
    expect(Customer.phoneFromInput(''), isNull);
    expect(Customer.phoneFromInput('   '), isNull);
    expect(Customer.normalizeIndonesianPhone(''), isNull);
    expect(Customer.isValidOptionalPhone(''), isTrue);
    expect(Customer.isValidOptionalPhone('08123456789'), isTrue);
    expect(Customer.normalizeIndonesianPhone('0812-3456-789'), '628123456789');
    expect(Customer.isValidOptionalPhone('123'), isFalse);
  });

  test('dua customer tanpa nomor bisa dibuat di preview fallback', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    final beforeCount = container.read(previewDataProvider).customers.length;

    final first = notifier.addCustomer(
      name: 'Budi',
      phone: '',
      address: '',
      note: '',
    );
    final second = notifier.addCustomer(
      name: 'Budi',
      phone: '   ',
      address: '',
      note: '',
    );

    final state = container.read(previewDataProvider);
    expect(first.normalizedPhone, isEmpty);
    expect(second.normalizedPhone, isEmpty);
    expect(state.customers.length, beforeCount + 2);
  });

  test('nomor customer yang sama tetap ditolak jika nomor tersedia', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(previewDataProvider.notifier);
    notifier.addCustomer(
      name: 'Siti',
      phone: '081234500001',
      address: '',
      note: '',
    );

    expect(
      () => notifier.addCustomer(
        name: 'Siti Lain',
        phone: '+62 812-3450-0001',
        address: '',
        note: '',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'reset pelanggan mengosongkan kontak tanpa menghapus pesanan preview',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(previewDataProvider.notifier);
      notifier.addCustomer(
        name: 'Pelanggan Reset',
        phone: '081234567890',
        address: '',
        note: '',
      );
      final before = container.read(previewDataProvider);
      expect(before.customers, isNotEmpty);

      final removedCount = notifier.resetCustomers();
      final after = container.read(previewDataProvider);

      expect(removedCount, before.customers.length);
      expect(after.customers, isEmpty);
      expect(after.orders.length, before.orders.length);
    },
  );

  test('WhatsApp pesanan tetap aktif saat snapshot nomor kosong', () {
    final order = PreviewOrder(
      id: 'order-no-phone',
      orderNumber: 'IDL-1',
      customerId: 'customer-no-phone',
      customerNameSnapshot: 'Pelanggan Tanpa Nomor',
      customerPhoneSnapshot: '',
      items: const [],
      totalPrice: 0,
      paidAmount: 0,
      orderStatus: PreviewOrderStatus.ready,
      paymentStatus: PreviewPaymentStatus.paid,
      receivedAt: DateTime(2026, 8, 14),
      dueAt: DateTime(2026, 8, 14),
      assignedEmployeeId: 'employee-1',
      note: '',
    );

    expect(orderHasReadyPickupWhatsApp(order), isTrue);
    expect(
      orderHasReadyPickupWhatsApp(
        order.copyWith(orderStatus: PreviewOrderStatus.processing),
      ),
      isFalse,
    );
  });

  test('hapus non-CS hanya mengubah kontak aplikasi', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(previewDataProvider.notifier);
    notifier.resetCustomers();
    notifier.addCustomer(
      name: 'CS Pagi',
      phone: '081200000001',
      address: '',
      note: '',
    );
    notifier.addCustomer(
      name: 'cs malam',
      phone: '081200000002',
      address: '',
      note: '',
    );
    notifier.addCustomer(
      name: 'Pelanggan Biasa',
      phone: '081200000003',
      address: '',
      note: '',
    );
    final orderCount = container.read(previewDataProvider).orders.length;

    expect(notifier.removeNonCsCustomers(), 1);
    final after = container.read(previewDataProvider);
    expect(after.customers.map((customer) => customer.name), [
      'CS Pagi',
      'cs malam',
    ]);
    expect(after.orders.length, orderCount);
  });

  test('pesan pembayaran WhatsApp menyebut metode dan sisa tagihan', () {
    final order = PreviewOrder(
      id: 'order-unpaid-pickup',
      orderNumber: 'IDL-8',
      customerId: 'customer-8',
      customerNameSnapshot: 'Dewi',
      customerPhoneSnapshot: '08123456789',
      items: const [],
      totalPrice: 30000,
      paidAmount: 10000,
      orderStatus: PreviewOrderStatus.pickedUp,
      paymentStatus: PreviewPaymentStatus.partiallyPaid,
      receivedAt: DateTime(2026, 9, 13),
      dueAt: DateTime(2026, 9, 14),
      assignedEmployeeId: 'employee-1',
      note: '',
    );

    final message = paymentWhatsAppMessage(order, 'QRIS');
    expect(message, contains('QRIS'));
    expect(message, contains('Rp20.000'));
    expect(message, contains('sudah diambil'));
  });
}
