import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_shell.dart';
import '../../../core/localization/app_language.dart';
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
    final strings = ref.strings;

    return Scaffold(
      appBar: AppBar(title: Text(strings.more)),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: role == UserRole.owner
              ? _ownerSections(context, ref, strings)
              : _employeeSections(context, ref, strings),
        ),
      ),
    );
  }

  List<Widget> _ownerSections(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) {
    return [
      _MenuSection(
        title: strings.operational,
        items: [
          _MenuItem(
            strings.servicesAndPrices,
            Icons.sell_outlined,
            AppRoutes.services,
          ),
          _MenuItem(
            strings.inventory,
            Icons.inventory_2_outlined,
            AppRoutes.inventory,
          ),
          _MenuItem(
            strings.shifts,
            Icons.calendar_month_outlined,
            AppRoutes.shifts,
          ),
        ],
      ),
      _MenuSection(
        title: strings.team,
        items: [
          _MenuItem(
            strings.employees,
            Icons.badge_outlined,
            AppRoutes.employees,
          ),
          _MenuItem(
            strings.attendance,
            Icons.fact_check_outlined,
            AppRoutes.attendance,
          ),
          _MenuItem(
            strings.payroll,
            Icons.account_balance_wallet_outlined,
            AppRoutes.payroll,
          ),
          _MenuItem(
            strings.requests,
            Icons.rule_folder_outlined,
            AppRoutes.requestReview,
          ),
        ],
      ),
      _MenuSection(
        title: strings.finance,
        items: [
          _MenuItem(
            strings.reports,
            Icons.assessment_outlined,
            AppRoutes.reports,
          ),
          _MenuItem(
            strings.cashbook,
            Icons.account_balance_outlined,
            AppRoutes.cashbook,
          ),
          _MenuItem(
            strings.expenses,
            Icons.price_check_outlined,
            AppRoutes.expenses,
          ),
        ],
      ),
      _MenuSection(
        title: strings.system,
        items: [
          _MenuItem(
            strings.notifications,
            Icons.notifications_outlined,
            AppRoutes.notifications,
          ),
          _MenuItem('Printer', Icons.print_outlined, AppRoutes.printer),
          _MenuItem(
            strings.backupData,
            Icons.cloud_upload_outlined,
            AppRoutes.backup,
          ),
          _MenuItem(
            strings.shopSettings,
            Icons.settings_outlined,
            AppRoutes.shopSettings,
          ),
          _MenuItem(
            strings.logout,
            Icons.logout,
            null,
            color: AppColors.error,
            onTap: () => confirmAndLogout(context, ref),
          ),
        ],
      ),
    ];
  }

  List<Widget> _employeeSections(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) {
    return [
      _MenuSection(
        title: strings.work,
        items: [
          _MenuItem(
            strings.mySchedule,
            Icons.calendar_today_outlined,
            AppRoutes.shiftsMine,
          ),
          _MenuItem(
            strings.myOrders,
            Icons.receipt_long_outlined,
            AppRoutes.ordersMine,
          ),
          _MenuItem(
            strings.addCustomer,
            Icons.person_add_alt_1,
            AppRoutes.customers,
          ),
          _MenuItem(
            strings.notifications,
            Icons.notifications_outlined,
            AppRoutes.notifications,
          ),
        ],
      ),
      _MenuSection(
        title: strings.requests.toUpperCase(),
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
        title: strings.account,
        items: [
          _MenuItem(strings.profile, Icons.person_outline, AppRoutes.profile),
          _MenuItem(strings.changePin, Icons.lock_reset, AppRoutes.changePin),
          _MenuItem(
            strings.logout,
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
