import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../router/app_routes.dart';
import 'app_snack_bar.dart';

class AppBackGuard extends ConsumerWidget {
  const AppBackGuard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role =
        ref.watch(authControllerProvider).value?.user?.role ??
        UserRole.employee;
    final path = GoRouterState.of(context).uri.path;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final target = _backTarget(path, role);
        if (target == null) {
          showAppSnackBar('Sudah di Beranda.');
          return;
        }
        context.go(target);
      },
      child: child,
    );
  }

  String? _backTarget(String path, UserRole role) {
    if (path == AppRoutes.dashboard) {
      return null;
    }
    final ordersRoot = role == UserRole.employee
        ? AppRoutes.ordersMine
        : AppRoutes.orders;
    if (path.startsWith('/orders')) {
      return path == ordersRoot ? AppRoutes.dashboard : ordersRoot;
    }
    if (path.startsWith('/customers')) {
      return path == AppRoutes.customers
          ? AppRoutes.dashboard
          : AppRoutes.customers;
    }
    if (path.startsWith('/attendance')) {
      return path == AppRoutes.attendanceMine || path == AppRoutes.attendance
          ? AppRoutes.dashboard
          : role == UserRole.employee
          ? AppRoutes.attendanceMine
          : AppRoutes.attendance;
    }
    if (path == AppRoutes.more) {
      return AppRoutes.dashboard;
    }
    return AppRoutes.more;
  }
}
