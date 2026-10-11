import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/cashbook/domain/payment_method_totals.dart';
import 'package:laundry_app_flutter/features/reports/presentation/payment_report_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('cash, TF, QRIS and mixed orders use the selected calendar range', () {
    final payments = [
      _payment('1', 'mixed', 20000, 'Cash', DateTime(2026, 10, 10, 8)),
      _payment('2', 'mixed', 30000, 'TF', DateTime(2026, 10, 11, 9)),
      _payment(
        '3',
        'transfer',
        50000,
        'Bank Transfer',
        DateTime(2026, 10, 11, 10),
      ),
      _payment('4', 'qr', 10000, 'QRIS', DateTime(2026, 10, 11, 11)),
      _payment('6', 'mixed', 7000, 'QRIS', DateTime(2026, 10, 11, 12)),
      _payment('5', 'cash', 5000, 'Tunai', DateTime(2026, 10, 12, 1)),
    ];

    final summary = CustomerPaymentSummary.forRange(
      payments,
      DateTime(2026, 10, 11),
      DateTime(2026, 10, 12),
    );

    expect(summary.methods['Tunai'], 0);
    expect(summary.methods['Transfer'], 80000);
    expect(summary.methods['QRIS'], 17000);
    expect(summary.total, 97000);
    expect(summary.paymentCount, 4);
    expect(summary.hybridOrderCount, 1);
    expect(summary.hybridAmountInRange, 30000);
    final message = paymentReportWhatsAppMessage(
      period: '11 Oktober 2026',
      senderName: 'Ratna',
      summary: summary,
    );
    expect(message, contains('Transfer/TF: Rp80.000'));
    expect(message, contains('Hybrid Tunai + Transfer: 1 pesanan'));
    expect(message, contains('jangan dijumlahkan lagi'));
  });

  test(
    'all cashbook income methods are grouped without including expenses',
    () {
      final totals = PaymentMethodTotals.fromTransactions([
        _cash('IN', 22000, 'tunai'),
        _cash('IN', 15000, 'tf'),
        _cash('IN', 3000, 'QR Code'),
        _cash('OUT', 5000, 'Transfer'),
      ], type: 'IN');
      expect(totals['Tunai'], 22000);
      expect(totals['Transfer'], 15000);
      expect(totals['QRIS'], 3000);
      expect(totals.amounts.values.reduce((a, b) => a + b), 40000);
    },
  );
}

PreviewPayment _payment(
  String id,
  String orderId,
  int amount,
  String method,
  DateTime date,
) => PreviewPayment(
  id: id,
  orderId: orderId,
  amount: amount,
  method: method,
  paidAt: date,
  receiverName: 'Ratna',
);

PreviewCashTransaction _cash(String type, int amount, String method) =>
    PreviewCashTransaction(
      id: '$type-$amount',
      referenceId: '',
      referenceType: '',
      type: type,
      category: 'Pembayaran',
      description: 'Test',
      amount: amount,
      method: method,
      createdAt: DateTime(2026, 10, 11),
    );
