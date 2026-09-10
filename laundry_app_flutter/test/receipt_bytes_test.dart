import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/services/bluetooth_receipt_printer.dart';

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
}
