import '../../../shared/preview_data.dart';

/// Amounts in the selected reporting period, grouped by actual payment method.
class PaymentMethodTotals {
  const PaymentMethodTotals(this.amounts);

  final Map<String, int> amounts;

  int operator [](String method) => amounts[method] ?? 0;

  static PaymentMethodTotals fromTransactions(
    Iterable<PreviewCashTransaction> transactions, {
    required String type,
  }) {
    final amounts = <String, int>{
      'Tunai': 0,
      'Transfer': 0,
      'QRIS': 0,
      'Lainnya': 0,
    };
    for (final entry in transactions) {
      if (entry.type != type) continue;
      final method = normalizePaymentMethod(entry.method);
      amounts[method] = amounts[method]! + entry.amount;
    }
    return PaymentMethodTotals(amounts);
  }
}

class CustomerPaymentSummary {
  const CustomerPaymentSummary({
    required this.methods,
    required this.paymentCount,
    required this.hybridOrderCount,
    required this.hybridAmountInRange,
  });

  final PaymentMethodTotals methods;
  final int paymentCount;
  final int hybridOrderCount;

  /// Already included in Tunai/Transfer totals; never add it again.
  final int hybridAmountInRange;

  int get total =>
      methods.amounts.values.fold(0, (sum, amount) => sum + amount);

  static CustomerPaymentSummary forRange(
    Iterable<PreviewPayment> allPayments,
    DateTime start,
    DateTime end,
  ) {
    final payments = allPayments.toList();
    final methodsByOrder = <String, Set<String>>{};
    for (final payment in payments) {
      methodsByOrder
          .putIfAbsent(payment.orderId, () => <String>{})
          .add(normalizePaymentMethod(payment.method));
    }
    final hybridOrderIds = {
      for (final entry in methodsByOrder.entries)
        if (entry.value.contains('Tunai') && entry.value.contains('Transfer'))
          entry.key,
    };
    final inRange = payments
        .where(
          (payment) =>
              !payment.paidAt.isBefore(start) && payment.paidAt.isBefore(end),
        )
        .toList();
    final amounts = <String, int>{
      'Tunai': 0,
      'Transfer': 0,
      'QRIS': 0,
      'Lainnya': 0,
    };
    for (final payment in inRange) {
      final method = normalizePaymentMethod(payment.method);
      amounts[method] = amounts[method]! + payment.amount;
    }
    final hybridInRange = inRange
        .where(
          (payment) =>
              hybridOrderIds.contains(payment.orderId) &&
              (normalizePaymentMethod(payment.method) == 'Tunai' ||
                  normalizePaymentMethod(payment.method) == 'Transfer'),
        )
        .toList();
    return CustomerPaymentSummary(
      methods: PaymentMethodTotals(amounts),
      paymentCount: inRange.length,
      hybridOrderCount: hybridInRange
          .map((payment) => payment.orderId)
          .toSet()
          .length,
      hybridAmountInRange: hybridInRange.fold(
        0,
        (sum, payment) => sum + payment.amount,
      ),
    );
  }
}

String normalizePaymentMethod(String value) {
  final method = value.trim().toLowerCase();
  if (method.contains('tunai') || method == 'cash') return 'Tunai';
  if (method.contains('qris') || method == 'qr' || method == 'qr code') {
    return 'QRIS';
  }
  if (method.contains('transfer') ||
      method == 'tf' ||
      method.startsWith('tf ') ||
      method.endsWith(' tf') ||
      method.contains('bank')) {
    return 'Transfer';
  }
  return 'Lainnya';
}
