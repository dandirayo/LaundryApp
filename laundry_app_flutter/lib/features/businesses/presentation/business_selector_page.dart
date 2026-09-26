import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/business.dart';
import 'business_controller.dart';

class BusinessSelectorPage extends ConsumerWidget {
  const BusinessSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final state = ref.watch(businessControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Usaha'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () =>
                ref.read(businessControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppStateView.error(
            title: 'Usaha gagal dimuat',
            message: '$error',
            actionLabel: 'Coba lagi',
            onAction: () =>
                ref.read(businessControllerProvider.notifier).refresh(),
          ),
          data: (data) => ListView(
            children: [
              Text(
                'Halo, ${user?.name.split(' ').first ?? 'Pengguna'}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih usaha yang ingin dibuka. Data setiap usaha tersimpan terpisah.',
                style: TextStyle(color: AppColors.secondaryText),
              ),
              const SizedBox(height: 20),
              if (data.businesses.isEmpty)
                AppStateView.empty(
                  title: 'Belum ada usaha',
                  message: user?.role == UserRole.owner
                      ? 'Tambahkan usaha pertama dari menu Kelola Usaha.'
                      : 'Minta owner menugaskan Anda ke sebuah usaha.',
                )
              else
                for (final business in data.businesses) ...[
                  _BusinessCard(
                    business: business,
                    onTap: business.isActive
                        ? () => _openBusiness(context, ref, business)
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
              if (user?.role == UserRole.owner) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () =>
                      AppNavigation.open(context, AppRoutes.businessManagement),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Kelola Usaha & Karyawan'),
                ),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => confirmAndLogout(context, ref),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dari akun'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBusiness(
    BuildContext context,
    WidgetRef ref,
    Business business,
  ) async {
    await ref
        .read(businessControllerProvider.notifier)
        .selectBusiness(business.id);
    if (!context.mounted) return;
    context.go(
      business.kind == BusinessKind.laundry
          ? AppRoutes.dashboard
          : AppRoutes.posHome,
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({required this.business, required this.onTap});

  final Business business;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLaundry = business.kind == BusinessKind.laundry;
    final color = isLaundry ? AppColors.primaryBlue : const Color(0xFF0F8B67);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isLaundry ? Icons.local_laundry_service : Icons.local_cafe,
                  color: color,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      business.kind.label,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: business.isActive
                            ? const Color(0xFFE3F4EA)
                            : const Color(0xFFF2F3F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        business.isActive ? 'AKTIF' : 'NONAKTIF',
                        style: TextStyle(
                          color: business.isActive
                              ? const Color(0xFF16794A)
                              : AppColors.secondaryText,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                business.isActive
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_outline,
                size: 18,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
