import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../app_updates/app_update_widgets.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../businesses/presentation/business_controller.dart';

class PosMorePage extends ConsumerWidget {
  const PosMorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).value?.user?.role;
    final business = ref
        .watch(businessControllerProvider)
        .value
        ?.selectedBusiness;
    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            if (business != null)
              Card(
                color: const Color(0xFFE5F5ED),
                child: ListTile(
                  leading: const Icon(
                    Icons.local_cafe,
                    color: Color(0xFF0F8B67),
                  ),
                  title: Text(
                    business.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('POS Minuman · Aktif'),
                ),
              ),
            const SizedBox(height: 8),
            const AppUpdateTile(),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.swap_horiz),
                    title: const Text('Ganti Usaha'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ref
                          .read(businessControllerProvider.notifier)
                          .clearSelection();
                      context.go(AppRoutes.businessSelector);
                    },
                  ),
                  if (role == UserRole.owner) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: const Text('Kelola Usaha & Karyawan'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go(AppRoutes.businessManagement),
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Profil'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(AppRoutes.profile),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.error),
                    title: const Text(
                      'Keluar',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () => confirmAndLogout(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
