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
  });
}
