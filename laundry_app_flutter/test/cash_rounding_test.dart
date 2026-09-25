import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/utils/order_total_rounding.dart';

void main() {
  test('always rounds a non-thousand total up to the next thousand', () {
    expect(roundOrderTotal(-1), 0);
    expect(roundOrderTotal(0), 0);
    expect(roundOrderTotal(22000), 22000);
    expect(roundOrderTotal(22001), 23000);
    expect(roundOrderTotal(22500), 23000);
    expect(roundOrderTotal(22999), 23000);
    expect(roundOrderTotal(32001), 33000);
    expect(roundOrderTotal(32999), 33000);
    expect(roundOrderTotal(32000.1), 33000);
  });
}
