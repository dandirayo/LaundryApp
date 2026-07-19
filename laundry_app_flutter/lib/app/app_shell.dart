import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_language.dart';
import '../core/router/app_routes.dart';
import '../core/widgets/confirmation_dialog.dart';
import '../features/auth/domain/user_role.dart';
import '../features/auth/presentation/auth_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).value;
    final role = session?.user?.role ?? UserRole.employee;
    final strings = ref.strings;
    final destinations = _destinationsFor(role, strings);
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path, destinations);

    return Scaffold(
      body: SafeArea(top: false, child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final destination = destinations[index];
          if (destination.path == path) {
            return;
          }
          context.go(destination.path);
        },
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  List<_ShellDestination> _destinationsFor(UserRole role, AppStrings strings) {
    if (role == UserRole.owner) {
      return [
        _ShellDestination(
          label: strings.home,
          path: AppRoutes.dashboard,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _ShellDestination(
          label: strings.orders,
          path: AppRoutes.orders,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
        ),
        _ShellDestination(
          label: strings.customers,
          path: AppRoutes.customers,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
        ),
        _ShellDestination(
          label: strings.more,
          path: AppRoutes.more,
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view,
        ),
      ];
    }

    return [
      _ShellDestination(
        label: strings.home,
        path: AppRoutes.dashboard,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _ShellDestination(
        label: strings.orders,
        path: AppRoutes.ordersMine,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _ShellDestination(
        label: strings.attendance,
        path: AppRoutes.attendanceMine,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
      ),
      _ShellDestination(
        label: strings.more,
        path: AppRoutes.more,
        icon: Icons.grid_view_outlined,
        selectedIcon: Icons.grid_view,
      ),
    ];
  }

  int _selectedIndex(String path, List<_ShellDestination> destinations) {
    final exactIndex = destinations.indexWhere((item) => item.path == path);
    if (exactIndex >= 0) {
      return exactIndex;
    }
    if (path.startsWith('/orders')) {
      return destinations.indexWhere((item) => item.path.startsWith('/orders'));
    }
    if (path.startsWith('/customers')) {
      return destinations.indexWhere(
        (item) => item.path == AppRoutes.customers,
      );
    }
    return destinations.indexWhere((item) => item.path == AppRoutes.more);
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;
}

Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final strings = ref.read(appLanguageProvider) == AppLanguage.en
      ? const AppStrings(AppLanguage.en)
      : const AppStrings(AppLanguage.id);
  final confirmed = await showConfirmationDialog(
    context,
    title: strings.logoutTitle,
    message: strings.logoutMessage,
    confirmLabel: strings.logout,
    isDestructive: true,
  );
  if (confirmed && context.mounted) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
