import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../attendance/presentation/attendance_controller.dart';
import '../../cashbook/presentation/cashbook_controller.dart';
import '../../customers/presentation/customer_controller.dart';
import '../../employee_requests/presentation/employee_request_controller.dart';
import '../../inventory/presentation/inventory_controller.dart';
import '../../notifications/presentation/notification_controller.dart';
import '../../orders/presentation/order_controller.dart';
import '../../shifts/presentation/shift_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;
    final role = user?.role ?? UserRole.employee;
    final strings = ref.strings;
    final today = DateTime.now();
    final previewNotifications = ref.watch(
      previewDataProvider.select((state) => state.notifications),
    );
    final notifications =
        ref.watch(notificationControllerProvider).value ?? previewNotifications;
    final unreadNotifications = notifications
        .where((notification) => !notification.isRead)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.home),
        actions: [
          const _OperationalSummaryAction(),
          IconButton(
            tooltip: strings.notifications,
            onPressed: () => context.go(AppRoutes.notifications),
            icon: Badge(
              isLabelVisible: unreadNotifications > 0,
              label: Text('$unreadNotifications'),
              child: const Icon(Icons.notifications_none),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(previewDataProvider);
          await ref.read(customerControllerProvider.notifier).refresh();
          await ref.read(cashbookControllerProvider.notifier).refresh();
          await ref.read(employeeRequestControllerProvider.notifier).refresh();
          await ref.read(orderControllerProvider.notifier).refresh();
          await ref.read(inventoryControllerProvider.notifier).refresh();
          await ref.read(shiftControllerProvider.notifier).refresh();
          await ref.read(attendanceControllerProvider.notifier).refresh();
          await ref.read(notificationControllerProvider.notifier).refresh();
          await Future<void>.delayed(const Duration(milliseconds: 250));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ResponsivePage(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${strings.isEnglish ? 'Hello' : 'Halo'}, ${user?.name.split(' ').first ?? (strings.isEnglish ? 'User' : 'Pengguna')}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${role.label} - ${today.toIndonesianDate()}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (ref.watch(orderControllerProvider).hasError ||
                    ref.watch(cashbookControllerProvider).hasError ||
                    ref.watch(cashbookControllerProvider).value?.syncFailed ==
                        true)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Data belum tersinkron. Tarik ke bawah untuk mencoba lagi.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                if (role == UserRole.owner)
                  const _OwnerDashboard()
                else
                  const _EmployeeDashboard(),
              ],
            ),
          ),
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
    final orders = ref.watch(orderControllerProvider).value ?? data.orders;
    final cashTransactions =
        ref.watch(cashbookControllerProvider).value?.transactions ??
        data.cashTransactions;
    final inventory =
        ref.watch(inventoryControllerProvider).value?.items ?? data.inventory;
    final strings = ref.strings;
    final today = DateTime.now();
    final todayOrders = orders.where((order) {
      return order.receivedAt.year == today.year &&
          order.receivedAt.month == today.month &&
          order.receivedAt.day == today.day;
    }).toList();
    final todayIncome = cashTransactions
        .where((cash) => cash.type == 'IN' && _isSameDay(cash.createdAt, today))
        .fold<int>(0, (sum, cash) => sum + cash.amount);
    final todayOut = cashTransactions
        .where(
          (cash) => cash.type == 'OUT' && _isSameDay(cash.createdAt, today),
        )
        .fold<int>(0, (sum, cash) => sum + cash.amount);
    final lowStock = inventory.where((item) => item.isLowStock).length;
    final pending = data.requests
        .where((request) => request.status == PreviewRequestStatus.pending)
        .length;
    final requestState = ref.watch(employeeRequestControllerProvider).value;
    final pendingRequests = requestState?.pendingCount ?? pending;
    final customerState = ref.watch(customerControllerProvider).value;
    final customerTotal = customerState?.totalCount ?? data.customers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryGrid(
          cards: [
            _MetricCard(
              label: strings.isEnglish ? 'Orders today' : 'Pesanan hari ini',
              value: '${todayOrders.length}',
              icon: Icons.receipt_long,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.orders),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Total customers' : 'Total pelanggan',
              value: '$customerTotal',
              icon: Icons.people,
              color: AppColors.softBlue,
              onTap: () => context.go(AppRoutes.customers),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Total kilograms' : 'Total kilogram',
              value:
                  '${todayOrders.fold<double>(0, (sum, order) => sum + order.laundryWeightKg).toStringAsFixed(1)} kg',
              icon: Icons.scale,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.reports),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Income today' : 'Pemasukan hari ini',
              value: todayIncome.toRupiah(),
              icon: Icons.payments,
              color: AppColors.primaryNavy,
              onTap: () => context.go(AppRoutes.cashbook),
            ),
            _MetricCard(
              label: strings.isEnglish
                  ? 'Expenses today'
                  : 'Pengeluaran hari ini',
              value: todayOut.toRupiah(),
              icon: Icons.trending_down,
              color: AppColors.error,
              onTap: () => context.go(AppRoutes.expenses),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Balance today' : 'Saldo hari ini',
              value: (todayIncome - todayOut).toRupiah(),
              icon: Icons.account_balance_wallet,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.cashbook),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Ready for pickup' : 'Siap diambil',
              value:
                  '${orders.where((order) => order.orderStatus == PreviewOrderStatus.ready).length}',
              icon: Icons.inventory_2,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.orders),
            ),
            _MetricCard(
              label: strings.isEnglish ? 'Low stock' : 'Stok menipis',
              value: '$lowStock',
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.inventory),
            ),
            _MetricCard(
              label: strings.isEnglish
                  ? 'Pending requests'
                  : 'Pengajuan pending',
              value: '$pendingRequests',
              icon: Icons.task_alt,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.requestReview),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
              strings.isEnglish ? 'Review Requests' : 'Review Pengajuan',
              Icons.rule_folder_outlined,
              AppRoutes.requestReview,
            ),
          ],
        ),
      ],
    );
  }
}

// Kept as an isolated dashboard section for the next staged dashboard pass.
// ignore: unused_element
class _LatestCustomersSection extends ConsumerWidget {
  const _LatestCustomersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.strings;
    final customersAsync = ref.watch(customerControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                strings.newCustomers,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go(AppRoutes.customers),
              icon: const Icon(Icons.arrow_forward),
              label: Text(strings.isEnglish ? 'View All' : 'Lihat Semua'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        customersAsync.when(
          data: (state) {
            final latest = state.latest(limit: 5);
            if (latest.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: Text(strings.noCustomersTitle),
                  subtitle: Text(strings.noCustomersMessage),
                ),
              );
            }
            return Column(
              children: [
                for (final customer in latest) ...[
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.softMint,
                        child: Text(
                          customer.name.trim().isEmpty
                              ? '?'
                              : customer.name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        customer.hasPhone
                            ? customer.phone!
                            : strings.phoneMissingShort,
                      ),
                      trailing: Text(
                        customer.createdAt.toIndonesianDate(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onTap: () => context.go(AppRoutes.customers),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            );
          },
          loading: () => const SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
          ),
          error: (error, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(
                strings.isEnglish
                    ? 'Customers could not be loaded'
                    : 'Pelanggan belum bisa dimuat',
              ),
              subtitle: Text(
                userErrorMessage(
                  error,
                  fallback: 'Data pelanggan belum siap. Coba lagi.',
                ),
              ),
              trailing: IconButton(
                tooltip: strings.isEnglish ? 'Retry' : 'Coba lagi',
                onPressed: () =>
                    ref.read(customerControllerProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh),
              ),
            ),
          ),
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
    final user = ref.watch(authControllerProvider).value?.user;
    final employeeId = _resolvePreviewEmployeeId(data, user);
    final requestState = ref.watch(employeeRequestControllerProvider).value;
    final orders = ref.watch(orderControllerProvider).value ?? data.orders;
    final shifts =
        ref.watch(shiftControllerProvider).value?.shifts ?? data.shifts;
    final attendance =
        ref.watch(attendanceControllerProvider).value ?? data.attendance;
    final requestSource = requestState?.requests ?? data.requests;
    final todayOrders = orders
        .where((order) => _isSameDay(order.receivedAt, DateTime.now()))
        .toList();
    final myAttendance = attendance
        .where((entry) => entry.employeeId == employeeId)
        .toList();
    final myRequests = requestSource
        .where(
          (request) =>
              request.employeeId == employeeId &&
              (request.status == PreviewRequestStatus.pending ||
                  request.status == PreviewRequestStatus.approved),
        )
        .toList();
    final todayShift = shifts
        .where(
          (shift) =>
              shift.employeeId == employeeId &&
              shift.day == _indonesianDay(DateTime.now()),
        )
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryGrid(
          cards: [
            _MetricCard(
              label: 'Shift hari ini',
              value: todayShift == null
                  ? '-'
                  : todayShift.isDayOff
                  ? 'Libur'
                  : '${todayShift.startTime}-${todayShift.endTime}',
              icon: Icons.calendar_today,
              color: AppColors.primaryBlue,
              onTap: () => context.go(AppRoutes.shiftsMine),
            ),
            _MetricCard(
              label: 'Status absensi',
              value: myAttendance.isEmpty ? 'Belum' : 'Hadir',
              icon: Icons.fact_check,
              color: AppColors.warning,
              onTap: () => context.go(AppRoutes.attendanceMine),
            ),
            _MetricCard(
              label: 'Pesanan hari ini',
              value: '${todayOrders.length}',
              icon: Icons.assignment,
              color: AppColors.primaryNavy,
              onTap: () => context.go(AppRoutes.ordersMine),
            ),
            _MetricCard(
              label: 'Pengajuan aktif',
              value: '${myRequests.length}',
              icon: Icons.pending_actions,
              color: AppColors.success,
              onTap: () => context.go(AppRoutes.requestsMine),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _QuickActions(
          title: 'Aksi cepat',
          actions: [
            _QuickAction(
              'Absen Masuk/Keluar',
              Icons.camera_alt,
              AppRoutes.attendanceMine,
            ),
            _QuickAction('Pesanan', Icons.receipt_long, AppRoutes.ordersMine),
            _QuickAction(
              'Pengajuan Saya',
              Icons.rule_folder_outlined,
              AppRoutes.requestsMine,
            ),
            _QuickAction(
              'Pengeluaran',
              Icons.price_check_outlined,
              AppRoutes.expenses,
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
        final columns = constraints.maxWidth >= 680 ? 4 : 3;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: columns == 4 ? 1.15 : 1.0,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cards,
        );
      },
    );
  }
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
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

String? _resolvePreviewEmployeeId(PreviewDataState data, AppUser? user) {
  final employeeId = user?.employeeId;
  if (employeeId != null &&
      data.employees.any((employee) => employee.id == employeeId)) {
    return employeeId;
  }

  if (user?.userId.startsWith('preview-') == true &&
      employeeId == 'preview-employee-1' &&
      data.employees.any((employee) => employee.id == 'employee-1')) {
    return 'employee-1';
  }

  final normalizedName = user?.name.trim().toLowerCase();
  if (normalizedName != null && normalizedName.isNotEmpty) {
    final byUsername = data.employees
        .where(
          (employee) =>
              employee.username.isNotEmpty &&
              employee.username.trim().toLowerCase() == normalizedName,
        )
        .firstOrNull;
    if (byUsername != null) {
      return byUsername.id;
    }

    final byName = data.employees
        .where(
          (employee) => employee.name.trim().toLowerCase() == normalizedName,
        )
        .firstOrNull;
    if (byName != null) {
      return byName.id;
    }
  }

  return employeeId;
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
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
            return InkWell(
              onTap: () => context.go(action.route),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(action.icon, color: AppColors.primaryBlue, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: AppColors.mainText,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.outline.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationalSummaryAction extends ConsumerWidget {
  const _OperationalSummaryAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(previewDataProvider);
    final requestState = ref.watch(employeeRequestControllerProvider).value;
    final orders = ref.watch(orderControllerProvider).value ?? data.orders;
    final inventory =
        ref.watch(inventoryControllerProvider).value?.items ?? data.inventory;
    final cashTransactions =
        ref.watch(cashbookControllerProvider).value?.transactions ??
        data.cashTransactions;
    final pendingRequests =
        requestState?.pendingCount ??
        data.requests
            .where((request) => request.status == PreviewRequestStatus.pending)
            .length;
    final attentionCount =
        pendingRequests +
        orders
            .where((order) => order.orderStatus == PreviewOrderStatus.ready)
            .length +
        inventory.where((item) => item.isLowStock).length;

    return IconButton(
      tooltip: 'Ringkasan operasional',
      onPressed: () => _showOperationalSummary(
        context,
        cashTransactions: cashTransactions,
        inventory: inventory,
        orders: orders,
        pendingRequests: pendingRequests,
      ),
      icon: attentionCount == 0
          ? const Icon(Icons.insights_outlined)
          : Badge.count(
              count: attentionCount,
              child: const Icon(Icons.insights_outlined),
            ),
    );
  }

  void _showOperationalSummary(
    BuildContext context, {
    required List<PreviewCashTransaction> cashTransactions,
    required List<PreviewInventoryItem> inventory,
    required List<PreviewOrder> orders,
    required int pendingRequests,
  }) {
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
          _OperationalSummaryList(
            cashTransactions: cashTransactions,
            inventory: inventory,
            orders: orders,
            pendingRequests: pendingRequests,
          ),
        ],
      ),
    );
  }
}

class _OperationalSummaryList extends StatelessWidget {
  const _OperationalSummaryList({
    required this.cashTransactions,
    required this.inventory,
    required this.orders,
    required this.pendingRequests,
  });

  final List<PreviewCashTransaction> cashTransactions;
  final List<PreviewInventoryItem> inventory;
  final List<PreviewOrder> orders;
  final int pendingRequests;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Perlu Perhatian', '$pendingRequests pengajuan menunggu persetujuan.'),
      (
        'Aktivitas Terbaru',
        cashTransactions.isEmpty
            ? 'Belum ada transaksi kas.'
            : cashTransactions.first.description,
      ),
      (
        'Pesanan Siap Diambil',
        '${orders.where((order) => order.orderStatus == PreviewOrderStatus.ready).length} pesanan siap diambil.',
      ),
      (
        'Stok Menipis',
        '${inventory.where((item) => item.isLowStock).length} barang di bawah minimum.',
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
