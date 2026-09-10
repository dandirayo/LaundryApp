import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/utils/order_total_rounding.dart';

void main() {
  test('rounds Rp500 down and Rp501 up', () {
    expect(roundOrderTotal(22000), 22000);
    expect(roundOrderTotal(22500), 22000);
    expect(roundOrderTotal(22501), 23000);
    expect(roundOrderTotal(22999), 23000);
  });
}
