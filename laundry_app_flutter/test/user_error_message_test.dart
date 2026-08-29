import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/errors/failure.dart';
import 'package:laundry_app_flutter/core/errors/user_error_message.dart';

void main() {
  const fallback = 'Data penggajian belum tersedia. Hubungi admin sistem.';

  test('raw database details are never exposed', () {
    final message = userErrorMessage(
      Exception('PostgrestException: PGRST205 schema cache relation missing'),
      fallback: fallback,
    );

    expect(message, fallback);
    expect(message, isNot(contains('PGRST')));
  });

  test('network failures get an operational retry message', () {
    expect(
      userErrorMessage(
        Exception('SocketException: Failed host lookup'),
        fallback: fallback,
      ),
      'Koneksi ke server terputus. Coba lagi beberapa saat.',
    );
  });

  test('safe domain failures preserve their useful message', () {
    expect(
      userErrorMessage(
        const Failure(message: 'Nomor telepon sudah digunakan.'),
        fallback: fallback,
      ),
      'Nomor telepon sudah digunakan.',
    );
  });
}
