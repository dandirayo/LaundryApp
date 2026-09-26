import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/user_role.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../router/app_routes.dart';
import '../router/app_navigation_history.dart';
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
    final routerCanPop = GoRouter.of(context).canPop();

    return PopScope(
      canPop: routerCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final target =
            AppNavigationHistory.instance.takePrevious() ??
            AppRoutes.parentFor(path, role);
        if (target == null) {
          showAppSnackBar('Sudah di Beranda.');
          return;
        }
        context.go(target);
      },
      child: child,
    );
  }
}
