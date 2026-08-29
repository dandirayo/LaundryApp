import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/payroll/presentation/payroll_controller.dart';
import 'package:laundry_app_flutter/features/payroll/presentation/payroll_page.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  await initializeDateFormatting('id_ID');
  testWidgets('payroll table error tidak tampil raw', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          payrollControllerProvider.overrideWith(_FailingPayrollController.new),
        ],
        child: const MaterialApp(home: PayrollPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Data penggajian belum dapat dimuat'), findsOneWidget);
    expect(
      find.text('Data penggajian belum tersedia. Hubungi admin sistem.'),
      findsOneWidget,
    );
    expect(find.textContaining('PostgrestException'), findsNothing);
    expect(find.textContaining('PGRST205'), findsNothing);
  });
}

class _FailingPayrollController extends PayrollController {
  @override
  Future<PayrollState> build() async {
    throw Exception(
      'PostgrestException: PGRST205 relation payroll_payments missing',
    );
  }
}
