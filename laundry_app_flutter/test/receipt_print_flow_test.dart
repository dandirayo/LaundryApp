import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/core/services/bluetooth_receipt_printer.dart';
import 'package:laundry_app_flutter/features/orders/presentation/receipt_preview_sheet.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  final date = DateTime(2026, 9, 18);
  final order = PreviewOrder(
    id: 'order-1',
    orderNumber: 'IDL-20260918-00001',
    customerId: 'customer-1',
    customerNameSnapshot: 'Ayu CS',
    customerPhoneSnapshot: '',
    items: const [
      PreviewOrderItem(
        id: 'item-1',
        serviceId: 'service-1',
        serviceNameSnapshot: 'Cuci Kering Lipat Express',
        unit: 'KG',
        quantity: 9.6,
        price: 6000,
        total: 57600,
      ),
    ],
    totalPrice: 58000,
    paidAmount: 29000,
    orderStatus: PreviewOrderStatus.received,
    paymentStatus: PreviewPaymentStatus.partiallyPaid,
    receivedAt: date,
    dueAt: date,
    assignedEmployeeId: 'employee-1',
    note: 'Jangan pakai pewangi',
  );

  testWidgets('nota dan label hanya punya tombol cetak satu per satu', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReceiptPreviewSheet(
                context: context,
                order: order,
                payments: const [],
                shopName: 'Idola Laundry',
                shopAddress: '',
                employeeName: 'Idola',
              ),
              child: const Text('Buka nota'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka nota'));
    await tester.pumpAndSettle();

    expect(find.text('Cetak Nota Pelanggan'), findsOneWidget);
    expect(find.textContaining('Nota + Label'), findsNothing);
    await tester.tap(find.text('Label Cucian'));
    await tester.pumpAndSettle();
    expect(find.text('Cetak Label Cucian'), findsOneWidget);
  });

  test('label 58 mm memisahkan berat dan layanan', () {
    final lines = laundryLabelLines(order, paperWidth: 58);
    expect(lines.any((line) => line.text == '9.6 KG' && line.large), isTrue);
    expect(
      lines.any(
        (line) => line.text == 'Cuci Kering Lipat Express' && !line.large,
      ),
      isTrue,
    );
    expect(
      lines.firstWhere((line) => line.text == order.orderNumber).large,
      isFalse,
    );

    final bytes = styledReceiptBytes(const [
      ThermalPrintLine('Cuci Kering Lipat Express', large: true),
    ], paperWidth: 58);
    expect(
      String.fromCharCodes(bytes),
      contains('Cuci Kering\nLipat Express\n'),
    );
  });
}
