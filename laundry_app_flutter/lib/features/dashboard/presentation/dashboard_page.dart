import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../core/widgets/summary_card.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final role = user?.role ?? UserRole.employee;
    final strings = ref.strings;
    final today = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.home),
        actions: [
          const _OperationalSummaryAction(),
          IconButton(
            tooltip: strings.notifications,
            onPressed: () => context.go(AppRoutes.notifications),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            Text(
              '${strings.isEnglish ? 'Hello' : 'Halo'}, ${user?.name ?? (strings.isEnglish ? 'User' : 'Pengguna')}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${role.label} - ${today.toIndonesianDate()}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            if (role == UserRole.owner)
              const _OwnerDashboard()
            else
              const _EmployeeDashboard(),
          ],
        ),
      ),
    );
  }
}

class _OwnerDashboard extends ConsumerWidget {
  const _OwnerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final strings = ref.strings;
    final today = DateTime.now();
    final todayOrders = data.orders.where((order) {
      return order.receivedAt.year == today.year &&
          order.receivedAt.month == today.month &&
          order.receivedAt.day == today.day;
    }).toList();
    final todayIncome = data.cashTransactions
        .where((cash) => cash.type == 'IN')
        .fold<int>(0, (sum, cash) => sum + cash.amount);
    final todayOut = data.cashTransactions
        .where((cash) => cash.type == 'OUT')
        .fold<int>(0, (sum, cash) => sum + cash.amount);
    final lowStock = data.inventory.where((item) => item.isLowStock).length;
    final pending = data.requests
        .where((request) => request.status == PreviewRequestStatus.pending)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryGrid(
          cards: [
            SummaryCard(
              label: strings.isEnglish ? 'Orders today' : 'Pesanan hari ini',
              value: '${todayOrders.length}',
              icon: Icons.receipt_long,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.orders),
            ),
            SummaryCard(
              label: strings.isEnglish
                  ? 'Customers today'
                  : 'Pelanggan hari ini',
              value: '${data.customers.length}',
              icon: Icons.people,
              color: AppColors.softBlue,
              onTap: () => context.go(AppRoutes.customers),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Total kilograms' : 'Total kilogram',
              value:
                  '${todayOrders.fold<double>(0, (sum, order) => sum + order.laundryWeightKg).toStringAsFixed(1)} kg',
              icon: Icons.scale,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.reports),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Income today' : 'Pemasukan hari ini',
              value: todayIncome.toRupiah(),
              icon: Icons.payments,
              color: AppColors.primaryNavy,
              onTap: () => context.go(AppRoutes.cashbook),
            ),
            SummaryCard(
              label: strings.isEnglish
                  ? 'Expenses today'
                  : 'Pengeluaran hari ini',
              value: todayOut.toRupiah(),
              icon: Icons.trending_down,
              color: AppColors.error,
              onTap: () => context.go(AppRoutes.expenses),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Balance today' : 'Saldo hari ini',
              value: (todayIncome - todayOut).toRupiah(),
              icon: Icons.account_balance_wallet,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.cashbook),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Ready for pickup' : 'Siap diambil',
              value:
                  '${data.orders.where((order) => order.orderStatus == PreviewOrderStatus.ready).length}',
              icon: Icons.inventory_2,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.orders),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Low stock' : 'Stok menipis',
              value: '$lowStock',
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.inventory),
            ),
            SummaryCard(
              label: strings.isEnglish ? 'Pending requests' : 'Request pending',
              value: '$pending',
              icon: Icons.task_alt,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.requestReview),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _QuickActions(
          title: strings.isEnglish ? 'Quick actions' : 'Aksi cepat',
          actions: [
            _QuickAction(strings.addOrder, Icons.add, AppRoutes.orderCreate),
            _QuickAction(
              strings.receivePayment,
              Icons.point_of_sale,
              AppRoutes.orders,
            ),
            _QuickAction(
              strings.isEnglish ? 'Add Stock' : 'Tambah Stok',
              Icons.add_box_outlined,
              AppRoutes.inventory,
            ),
            _QuickAction(
              strings.isEnglish ? 'View Attendance' : 'Lihat Absensi',
              Icons.fact_check,
              AppRoutes.attendance,
            ),
            _QuickAction(
              strings.isEnglish ? 'View Cashbook' : 'Lihat Buku Kas',
              Icons.account_balance,
              AppRoutes.cashbook,
            ),
            _QuickAction(
              strings.isEnglish ? 'Review Requests' : 'Review Request',
              Icons.rule_folder_outlined,
              AppRoutes.requestReview,
            ),
          ],
        ),
      ],
    );
  }
}

class _EmployeeDashboard extends ConsumerWidget {
  const _EmployeeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final myOrders = data.orders
        .where((order) => order.assignedEmployeeId == 'employee-1')
        .toList();
    final myAttendance = data.attendance
        .where((entry) => entry.employeeId == 'employee-1')
        .toList();
    final myRequests = data.requests
        .where((request) => request.employeeId == 'employee-1')
        .toList();
    final todayShift = data.shifts
        .where(
          (shift) =>
              shift.employeeId == 'employee-1' &&
              shift.day == _indonesianDay(DateTime.now()),
        )
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryGrid(
          cards: [
            SummaryCard(
              label: 'Shift hari ini',
              value: todayShift == null
                  ? '-'
                  : '${todayShift.startTime}-${todayShift.endTime}',
              icon: Icons.calendar_today,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.shiftsMine),
            ),
            SummaryCard(
              label: 'Status absensi',
              value: myAttendance.isEmpty ? 'Belum' : 'Hadir',
              icon: Icons.fact_check,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.attendanceMine),
            ),
            SummaryCard(
              label: 'Pesanan saya',
              value: '${myOrders.length}',
              icon: Icons.assignment,
              color: AppColors.primaryNavy,
              onTap: () => context.go(AppRoutes.ordersMine),
            ),
            SummaryCard(
              label: 'Request aktif',
              value: '${myRequests.length}',
              icon: Icons.pending_actions,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.more),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _QuickActions(
          title: 'Aksi cepat',
          actions: [
            _QuickAction(
              'Absen Masuk/Keluar',
              Icons.camera_alt,
              AppRoutes.attendanceMine,
            ),
            _QuickAction(
              'Pesanan Saya',
              Icons.receipt_long,
              AppRoutes.ordersMine,
            ),
            _QuickAction(
              'Request Stok',
              Icons.add_shopping_cart,
              AppRoutes.stockRequest,
            ),
            _QuickAction(
              'Request Lembur',
              Icons.alarm_add,
              AppRoutes.overtimeRequest,
            ),
            _QuickAction(
              'Lihat Jadwal',
              Icons.event_note,
              AppRoutes.shiftsMine,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 680 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 4 ? 1.15 : 1.05,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

String _indonesianDay(DateTime date) {
  return switch (date.weekday) {
    DateTime.monday => 'Senin',
    DateTime.tuesday => 'Selasa',
    DateTime.wednesday => 'Rabu',
    DateTime.thursday => 'Kamis',
    DateTime.friday => 'Jumat',
    DateTime.saturday => 'Sabtu',
    DateTime.sunday => 'Minggu',
    _ => 'Senin',
  };
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.title, required this.actions});

  final String title;
  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final action in actions)
              SizedBox(
                width: 164,
                child: OutlinedButton.icon(
                  onPressed: () => context.go(action.route),
                  icon: Icon(action.icon),
                  label: Text(action.label),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

class _OperationalSummaryAction extends ConsumerWidget {
  const _OperationalSummaryAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final attentionCount =
        data.requests
            .where((request) => request.status == PreviewRequestStatus.pending)
            .length +
        data.orders
            .where((order) => order.orderStatus == PreviewOrderStatus.ready)
            .length +
        data.inventory.where((item) => item.isLowStock).length;

    return IconButton(
      tooltip: 'Ringkasan operasional',
      onPressed: () => _showOperationalSummary(context, data),
      icon: attentionCount == 0
          ? const Icon(Icons.insights_outlined)
          : Badge.count(
              count: attentionCount,
              child: const Icon(Icons.insights_outlined),
            ),
    );
  }

  void _showOperationalSummary(BuildContext context, PreviewDataState data) {
    showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => AppBottomSheetBody(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Ringkasan operasional',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 12),
          _OperationalSummaryList(data: data),
        ],
      ),
    );
  }
}

class _OperationalSummaryList extends StatelessWidget {
  const _OperationalSummaryList({required this.data});

  final PreviewDataState data;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Perlu Perhatian',
        '${data.requests.where((request) => request.status == PreviewRequestStatus.pending).length} request menunggu persetujuan.',
      ),
      (
        'Aktivitas Terbaru',
        data.cashTransactions.isEmpty
            ? 'Belum ada transaksi kas.'
            : data.cashTransactions.first.description,
      ),
      (
        'Pesanan Siap Diambil',
        '${data.orders.where((order) => order.orderStatus == PreviewOrderStatus.ready).length} pesanan siap diambil.',
      ),
      (
        'Stok Menipis',
        '${data.inventory.where((item) => item.isLowStock).length} barang di bawah minimum.',
      ),
    ];
    return Column(
      children: [
        for (final item in items) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: Text(item.$1),
            subtitle: Text(item.$2),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }
}
