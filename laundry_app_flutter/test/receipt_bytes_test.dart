import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/services/bluetooth_receipt_printer.dart';
import 'package:laundry_app_flutter/features/orders/presentation/receipt_preview_sheet.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('long receipt lines retain all text within paper columns', () {
    for (final width in [58, 80]) {
      final source = 'Laundry ${'1234567890' * 10}';
      final payload = String.fromCharCodes(
        receiptBytes([source], paperWidth: width).skip(8),
      );
      final lines = payload.split('\n');
      expect(lines.join(), source);
      expect(
        lines.every((line) => line.length <= (width == 58 ? 32 : 48)),
        isTrue,
      );
    }
  });

  test('customer text cannot inject ESC/POS control commands', () {
    final payload = receiptBytes(['Nama\x1b@\x1dV\nTest']).skip(8).toList();
    expect(payload, isNot(contains(27)));
    expect(payload, isNot(contains(29)));
    expect(String.fromCharCodes(payload), startsWith('Nama @ V Test\n'));
  });

  test('laundry label uses large text and contains operational details', () {
    final order = PreviewOrder(
      id: 'order-label',
      orderNumber: 'IDL-42',
      customerId: 'customer-1',
      customerNameSnapshot: 'Rina',
      customerPhoneSnapshot: '081234567890',
      items: const [
        PreviewOrderItem(
          id: 'item-1',
          serviceId: 'service-1',
          serviceNameSnapshot: 'Cuci Setrika',
          unit: 'KG',
          quantity: 3,
          price: 7000,
          total: 21000,
        ),
      ],
      totalPrice: 21000,
      paidAmount: 0,
      orderStatus: PreviewOrderStatus.received,
      paymentStatus: PreviewPaymentStatus.unpaid,
      receivedAt: DateTime(2026, 9, 13),
      dueAt: DateTime(2026, 9, 14),
      assignedEmployeeId: 'employee-1',
      note: 'Pisahkan pakaian putih',
    );

    final lines = laundryLabelLines(order);
    expect(lines.any((line) => line.large), isTrue);
    expect(lines.map((line) => line.text).join(' '), contains('3 KG'));
    expect(lines.map((line) => line.text).join(' '), contains('BELUM'));
    expect(
      lines.map((line) => line.text).join(' '),
      contains('PISAHKAN PAKAIAN PUTIH'),
    );
    final bytes = styledReceiptBytes(lines, paperWidth: 58);
    expect(bytes, containsAllInOrder([29, 33, 17]));
  });
}
