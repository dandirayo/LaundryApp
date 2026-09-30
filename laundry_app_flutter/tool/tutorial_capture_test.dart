import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/core/theme/app_theme.dart';
import 'package:laundry_app_flutter/features/attendance/presentation/attendance_page.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/customers/presentation/customers_page.dart';
import 'package:laundry_app_flutter/features/dashboard/presentation/dashboard_page.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/request_page.dart';
import 'package:laundry_app_flutter/features/expenses/presentation/expenses_page.dart';
import 'package:laundry_app_flutter/features/notifications/presentation/notifications_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/order_create_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/order_detail_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/orders_page.dart';
import 'package:laundry_app_flutter/features/settings/presentation/more_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    await (FontLoader(
      'DM Sans',
    )..addFont(rootBundle.load('assets/fonts/DMSans-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  final captures = <(String, Widget Function(ProviderContainer))>[
    ('01-beranda-karyawan', (_) => const DashboardPage()),
    ('02-daftar-pesanan', (_) => const OrdersPage()),
    ('03-buat-pesanan', (_) => const OrderCreatePage()),
    ('04-pelanggan', (_) => const CustomersPage()),
    ('05-absensi', (_) => const AttendancePage(showMineOnly: true)),
    ('06-pengajuan', (_) => const RequestPage()),
    ('07-stok-pengeluaran', (_) => const ExpensesPage()),
    ('08-notifikasi', (_) => const NotificationsPage()),
    ('09-menu-lainnya', (_) => const MorePage()),
    (
      '10-detail-pesanan',
      (container) => OrderDetailPage(
        orderId: container.read(previewDataProvider).orders.first.id,
      ),
    ),
  ];

  for (final capture in captures) {
    testWidgets('capture ${capture.$1}', (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(780, 1688);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith(_EmployeeAuth.new)],
      );
      addTearDown(container.dispose);
      final state = container.read(previewDataProvider);
      container
          .read(previewDataProvider.notifier)
          .createOrderWithItems(
            customerId: state.customers.first.id,
            items: [(serviceId: state.services.first.id, quantity: 3)],
            paidAmount: 0,
            paymentMethod: 'Tunai',
            employeeId: state.employees.first.id,
            note: 'Pisahkan pakaian berwarna.',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: RepaintBoundary(
              key: const ValueKey('tutorial-capture'),
              child: capture.$2(container),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 250));
      await expectLater(
        find.byKey(const ValueKey('tutorial-capture')),
        matchesGoldenFile('../../tutorial-karyawan/images/${capture.$1}.png'),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

class _EmployeeAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(
        AppUser(
          userId: 'tutorial-employee',
          shopId: 'preview-shop',
          employeeId: 'employee-1',
          name: 'Budi',
          role: UserRole.employee,
          isActive: true,
        ),
      );
}
