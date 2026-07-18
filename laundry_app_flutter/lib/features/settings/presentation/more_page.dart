import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider).value?.user?.role;

    return Scaffold(
      appBar: AppBar(title: const Text('Lainnya')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: role == UserRole.owner
              ? _ownerSections(context, ref)
              : _employeeSections(context, ref),
        ),
      ),
    );
  }

  List<Widget> _ownerSections(BuildContext context, WidgetRef ref) {
    return [
      _MenuSection(
        title: 'OPERASIONAL',
        items: [
          _MenuItem('Layanan & Harga', Icons.sell_outlined, AppRoutes.services),
          _MenuItem(
            'Stok & Pengadaan',
            Icons.inventory_2_outlined,
            AppRoutes.inventory,
          ),
          _MenuItem(
            'Jadwal Shift',
            Icons.calendar_month_outlined,
            AppRoutes.shifts,
          ),
        ],
      ),
      _MenuSection(
        title: 'TIM',
        items: [
          _MenuItem('Data Karyawan', Icons.badge_outlined, AppRoutes.employees),
          _MenuItem(
            'Absensi Karyawan',
            Icons.fact_check_outlined,
            AppRoutes.attendance,
          ),
          _MenuItem(
            'Gaji & Insentif',
            Icons.account_balance_wallet_outlined,
            AppRoutes.payroll,
          ),
          _MenuItem(
            'Review Request',
            Icons.rule_folder_outlined,
            AppRoutes.requestReview,
          ),
        ],
      ),
      _MenuSection(
        title: 'KEUANGAN',
        items: [
          _MenuItem('Laporan', Icons.assessment_outlined, AppRoutes.reports),
          _MenuItem(
            'Buku Kas',
            Icons.account_balance_outlined,
            AppRoutes.cashbook,
          ),
          _MenuItem(
            'Pengeluaran',
            Icons.price_check_outlined,
            AppRoutes.expenses,
          ),
        ],
      ),
      _MenuSection(
        title: 'SISTEM',
        items: [
          _MenuItem(
            'Notifikasi',
            Icons.notifications_outlined,
            AppRoutes.notifications,
          ),
          _MenuItem('Printer', Icons.print_outlined, AppRoutes.printer),
          _MenuItem(
            'Backup Data',
            Icons.cloud_upload_outlined,
            AppRoutes.backup,
          ),
          _MenuItem(
            'Pengaturan Toko',
            Icons.settings_outlined,
            AppRoutes.shopSettings,
          ),
          _MenuItem(
            'Keluar',
            Icons.logout,
            null,
            color: AppColors.error,
            onTap: () => confirmAndLogout(context, ref),
          ),
        ],
      ),
    ];
  }

  List<Widget> _employeeSections(BuildContext context, WidgetRef ref) {
    return [
      _MenuSection(
        title: 'PEKERJAAN',
        items: [
          _MenuItem(
            'Jadwal Saya',
            Icons.calendar_today_outlined,
            AppRoutes.shiftsMine,
          ),
          _MenuItem(
            'Pesanan Saya',
            Icons.receipt_long_outlined,
            AppRoutes.ordersMine,
          ),
          _MenuItem(
            'Notifikasi',
            Icons.notifications_outlined,
            AppRoutes.notifications,
          ),
        ],
      ),
      _MenuSection(
        title: 'REQUEST',
        items: [
          _MenuItem(
            'Request Stok',
            Icons.add_shopping_cart,
            AppRoutes.stockRequest,
          ),
          _MenuItem(
            'Request Lembur',
            Icons.alarm_add_outlined,
            AppRoutes.overtimeRequest,
          ),
          _MenuItem(
            'Request Tukar Shift',
            Icons.swap_horiz,
            AppRoutes.shiftSwapRequest,
          ),
          _MenuItem(
            'Request Izin',
            Icons.event_busy_outlined,
            AppRoutes.leaveRequest,
          ),
          _MenuItem(
            'Request Insentif',
            Icons.star_outline,
            AppRoutes.incentiveRequest,
          ),
          _MenuItem(
            'Request Kasbon',
            Icons.payments_outlined,
            AppRoutes.cashAdvanceRequest,
          ),
        ],
      ),
      _MenuSection(
        title: 'AKUN',
        items: [
          _MenuItem('Profil', Icons.person_outline, AppRoutes.profile),
          _MenuItem('Ganti PIN', Icons.lock_reset, AppRoutes.changePin),
          _MenuItem(
            'Keluar',
            Icons.logout,
            null,
            color: AppColors.error,
            onTap: () => confirmAndLogout(context, ref),
          ),
        ],
      ),
    ];
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.items});

  final String title;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _MenuTile(item: items[index]),
                  if (index < items.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 56,
      leading: Icon(item.icon, color: item.color ?? AppColors.primaryBlue),
      title: Text(
        item.label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: item.color ?? AppColors.mainText,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap:
          item.onTap ??
          (item.route == null ? null : () => context.go(item.route!)),
    );
  }
}

class _MenuItem {
  const _MenuItem(this.label, this.icon, this.route, {this.color, this.onTap});

  final String label;
  final IconData icon;
  final String? route;
  final Color? color;
  final VoidCallback? onTap;
}
