import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/router/app_navigation_history.dart';

void main() {
  test('back follows the actual sequence of visited menus', () {
    final history = AppNavigationHistory();
    history.record('/dashboard');
    history.record('/expenses');
    history.record('/inventory');

    expect(history.takePrevious(), '/expenses');
    history.record('/expenses');
    expect(history.takePrevious(), '/dashboard');
  });

  test('a fresh sign-in clears the previous user navigation', () {
    final history = AppNavigationHistory();
    history.record('/dashboard');
    history.record('/orders');
    history.record('/sign-in');
    history.record('/businesses');

    expect(history.previous, isNull);
  });
}
