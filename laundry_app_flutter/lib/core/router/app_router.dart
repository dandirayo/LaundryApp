import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/attendance/presentation/attendance_page.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/change_pin_page.dart';
import '../../features/auth/presentation/profile_page.dart';
import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/backup/presentation/backup_page.dart';
import '../../features/cashbook/presentation/cashbook_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/employee_requests/presentation/request_page.dart';
import '../../features/employee_requests/presentation/request_review_page.dart';
import '../../features/employees/presentation/employees_page.dart';
import '../../features/expenses/presentation/expenses_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/notifications/presentation/notifications_page.dart';
import '../../features/orders/presentation/order_create_page.dart';
import '../../features/orders/presentation/order_detail_page.dart';
import '../../features/orders/presentation/orders_page.dart';
import '../../features/payroll/presentation/payroll_page.dart';
import '../../features/printer/presentation/printer_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/services/presentation/services_page.dart';
import '../../features/settings/presentation/more_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shifts/presentation/shifts_page.dart';
import '../widgets/app_back_guard.dart';
import '../widgets/feature_status_page.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final session = auth.value;

  return GoRouter(
    initialLocation: AppRoutes.splash,
    redirect: (context, state) {
      final path = state.uri.path;
      final isSplash = path == AppRoutes.splash;
      final isSignIn = path == AppRoutes.signIn;
      final isChecking = auth.isLoading && session == null;

      if (isChecking) {
        return isSplash ? null : AppRoutes.splash;
      }

      final user = session?.user;
      if (user == null) {
        return isSignIn ? null : AppRoutes.signIn;
      }

      if (isSplash || isSignIn) {
        return AppRoutes.dashboard;
      }

      if (!AppRoutes.canOpen(path, user.role)) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const SignInPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => _withBackGuard(const DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.orders,
            builder: (context, state) => _withBackGuard(const OrdersPage()),
          ),
          GoRoute(
            path: AppRoutes.ordersMine,
            builder: (context, state) =>
                _withBackGuard(const OrdersPage(showMineOnly: true)),
          ),
          GoRoute(
            path: AppRoutes.orderCreate,
            builder: (context, state) =>
                _withBackGuard(const OrderCreatePage()),
          ),
          GoRoute(
            path: AppRoutes.orderDetail,
            builder: (context, state) => _withBackGuard(
              OrderDetailPage(orderId: state.pathParameters['orderId'] ?? ''),
            ),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => _withBackGuard(const CustomersPage()),
          ),
          GoRoute(
            path: AppRoutes.more,
            builder: (context, state) => _withBackGuard(const MorePage()),
          ),
          GoRoute(
            path: AppRoutes.services,
            builder: (context, state) => _withBackGuard(const ServicesPage()),
          ),
          GoRoute(
            path: AppRoutes.inventory,
            builder: (context, state) => _withBackGuard(const InventoryPage()),
          ),
          GoRoute(
            path: AppRoutes.shifts,
            builder: (context, state) => _withBackGuard(const ShiftsPage()),
          ),
          GoRoute(
            path: AppRoutes.shiftsMine,
            builder: (context, state) =>
                _withBackGuard(const ShiftsPage(showMineOnly: true)),
          ),
          GoRoute(
            path: AppRoutes.employees,
            builder: (context, state) => _withBackGuard(const EmployeesPage()),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            builder: (context, state) => _withBackGuard(const AttendancePage()),
          ),
          GoRoute(
            path: AppRoutes.attendanceMine,
            builder: (context, state) =>
                _withBackGuard(const AttendancePage(showMineOnly: true)),
          ),
          GoRoute(
            path: AppRoutes.payroll,
            builder: (context, state) => _withBackGuard(const PayrollPage()),
          ),
          GoRoute(
            path: AppRoutes.requestReview,
            builder: (context, state) =>
                _withBackGuard(const RequestReviewPage()),
          ),
          GoRoute(
            path: AppRoutes.reports,
            builder: (context, state) => _withBackGuard(const ReportsPage()),
          ),
          GoRoute(
            path: AppRoutes.cashbook,
            builder: (context, state) => _withBackGuard(const CashbookPage()),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            builder: (context, state) => _withBackGuard(const ExpensesPage()),
          ),
          GoRoute(
            path: AppRoutes.notifications,
            builder: (context, state) =>
                _withBackGuard(const NotificationsPage()),
          ),
          GoRoute(
            path: AppRoutes.printer,
            builder: (context, state) => _withBackGuard(const PrinterPage()),
          ),
          GoRoute(
            path: AppRoutes.backup,
            builder: (context, state) => _withBackGuard(const BackupPage()),
          ),
          GoRoute(
            path: AppRoutes.shopSettings,
            builder: (context, state) => _withBackGuard(const SettingsPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => _withBackGuard(const ProfilePage()),
          ),
          GoRoute(
            path: AppRoutes.stockRequest,
            builder: (context, state) =>
                _withBackGuard(const RequestPage(typeLabel: 'Request Stok')),
          ),
          GoRoute(
            path: AppRoutes.overtimeRequest,
            builder: (context, state) =>
                _withBackGuard(const RequestPage(typeLabel: 'Request Lembur')),
          ),
          GoRoute(
            path: AppRoutes.shiftSwapRequest,
            builder: (context, state) => _withBackGuard(
              const RequestPage(typeLabel: 'Request Tukar Shift'),
            ),
          ),
          GoRoute(
            path: AppRoutes.leaveRequest,
            builder: (context, state) =>
                _withBackGuard(const RequestPage(typeLabel: 'Request Izin')),
          ),
          GoRoute(
            path: AppRoutes.incentiveRequest,
            builder: (context, state) => _withBackGuard(
              const RequestPage(typeLabel: 'Request Insentif'),
            ),
          ),
          GoRoute(
            path: AppRoutes.cashAdvanceRequest,
            builder: (context, state) =>
                _withBackGuard(const RequestPage(typeLabel: 'Request Kasbon')),
          ),
          GoRoute(
            path: AppRoutes.changePin,
            builder: (context, state) => _withBackGuard(const ChangePinPage()),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => const FeatureStatusPage(
      title: 'Halaman tidak ditemukan',
      phase: 'Routing',
      icon: Icons.search_off,
      description:
          'Route tidak dikenali. Gunakan navigasi aplikasi untuk kembali.',
    ),
  );
});

Widget _withBackGuard(Widget child) => AppBackGuard(child: child);
