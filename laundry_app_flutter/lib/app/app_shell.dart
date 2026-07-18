import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_routes.dart';
import '../core/theme/app_colors.dart';
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
    final destinations = _destinationsFor(role);
    final path = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(path, destinations);

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const _OfflineBanner(),
            Expanded(child: child),
          ],
        ),
      ),
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

  List<_ShellDestination> _destinationsFor(UserRole role) {
    if (role == UserRole.owner) {
      return const [
        _ShellDestination(
          label: 'Beranda',
          path: AppRoutes.dashboard,
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
        ),
        _ShellDestination(
          label: 'Pesanan',
          path: AppRoutes.orders,
          icon: Icons.receipt_long_outlined,
          selectedIcon: Icons.receipt_long,
        ),
        _ShellDestination(
          label: 'Pelanggan',
          path: AppRoutes.customers,
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
        ),
        _ShellDestination(
          label: 'Lainnya',
          path: AppRoutes.more,
          icon: Icons.grid_view_outlined,
          selectedIcon: Icons.grid_view,
        ),
      ];
    }

    return const [
      _ShellDestination(
        label: 'Beranda',
        path: AppRoutes.dashboard,
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      _ShellDestination(
        label: 'Pesanan',
        path: AppRoutes.ordersMine,
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
      ),
      _ShellDestination(
        label: 'Absensi',
        path: AppRoutes.attendanceMine,
        icon: Icons.fact_check_outlined,
        selectedIcon: Icons.fact_check,
      ),
      _ShellDestination(
        label: 'Lainnya',
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softMint,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Mode online siap. Cache offline akan aktif pada Phase 6.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> confirmAndLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await showConfirmationDialog(
    context,
    title: 'Keluar dari akun?',
    message:
        'Session, provider sensitif, cache auth, dan subscription akan dibersihkan.',
    confirmLabel: 'Keluar',
    isDestructive: true,
  );
  if (confirmed && context.mounted) {
    await ref.read(authControllerProvider.notifier).signOut();
  }
}
