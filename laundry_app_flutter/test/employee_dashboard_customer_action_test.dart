import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/dashboard/presentation/dashboard_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('beranda karyawan menyediakan tombol Pelanggan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authControllerProvider.overrideWith(_EmployeeAuth.new)],
        child: const MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aksi cepat'), findsOneWidget);
    expect(find.text('Pelanggan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _EmployeeAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(
        AppUser(
          userId: 'employee-user',
          shopId: 'preview-shop',
          employeeId: 'employee-1',
          name: 'Karyawan',
          role: UserRole.employee,
          isActive: true,
        ),
      );
}
