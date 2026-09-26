import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/errors/user_error_message.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';
import 'notification_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewNotifications = ref.watch(
      previewDataProvider.select((state) => state.notifications),
    );
    final online = ref.watch(notificationControllerProvider);
    final notifications = online.value ?? previewNotifications;
    final role =
        ref.watch(authControllerProvider).value?.user?.role ??
        UserRole.employee;
    final unreadCount = notifications.where((item) => !item.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: unreadCount == 0
                ? null
                : () async {
                    try {
                      await ref
                          .read(notificationControllerProvider.notifier)
                          .markAllRead();
                    } catch (error) {
                      showAppSnackBar(
                        userErrorMessage(
                          error,
                          fallback: 'Notifikasi belum berhasil diperbarui.',
                        ),
                      );
                    }
                  },
            child: const Text('Tandai semua'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationControllerProvider.notifier).refresh(),
        child: ResponsivePage(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: online.isLoading && online.value == null
              ? const LoadingStateView()
              : online.hasError && online.value == null
              ? AppStateView.error(
                  title: 'Notifikasi belum bisa dimuat',
                  message: userErrorMessage(
                    online.error!,
                    fallback: 'Periksa koneksi lalu coba lagi.',
                  ),
                  actionLabel: 'Coba lagi',
                  onAction: () => ref
                      .read(notificationControllerProvider.notifier)
                      .refresh(),
                )
              : notifications.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 72),
                    AppStateView.empty(
                      title: 'Tidak ada notifikasi',
                      message:
                          'Pembaruan pesanan dan aktivitas akan muncul di sini. Tarik ke bawah untuk memuat ulang.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: notifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return Card(
                      color: notification.isRead
                          ? null
                          : AppColors.softBlue.withValues(alpha: 0.55),
                      child: ListTile(
                        leading: Badge(
                          isLabelVisible: !notification.isRead,
                          smallSize: 8,
                          child: Icon(
                            notification.isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: notification.isRead
                                ? AppColors.secondaryText
                                : AppColors.primaryBlue,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${notification.message}\n${notification.createdAt.toIndonesianDate()} ${notification.createdAt.toIndonesianTime()}',
                        ),
                        isThreeLine: true,
                        onTap: () async {
                          final route = notificationRouteFor(
                            notification,
                            role,
                          );
                          try {
                            await ref
                                .read(notificationControllerProvider.notifier)
                                .markRead(notification.id);
                          } catch (error) {
                            showAppSnackBar(
                              userErrorMessage(
                                error,
                                fallback:
                                    'Status baca notifikasi belum tersimpan.',
                              ),
                            );
                          }
                          if (!context.mounted) return;
                          if (route != null) {
                            AppNavigation.open(context, route);
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            try {
                              await ref
                                  .read(notificationControllerProvider.notifier)
                                  .delete(notification.id);
                            } catch (error) {
                              showAppSnackBar(
                                userErrorMessage(
                                  error,
                                  fallback:
                                      'Notifikasi belum berhasil dihapus.',
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

String? notificationRouteFor(PreviewNotification notification, UserRole role) {
  final route = notification.actionRoute.trim();
  if (_isKnownNotificationRoute(route)) return route;
  return switch (notification.referenceType.toLowerCase()) {
    'order' || 'orders' || 'order_workflow' || 'order_unpaid_reminder' =>
      notification.referenceId == null
          ? AppRoutes.orders
          : '/orders/${notification.referenceId}',
    'employee_request' || 'employee_requests' =>
      role == UserRole.owner ? AppRoutes.requestReview : AppRoutes.requestsMine,
    'weekly_shift' || 'weekly_shifts' =>
      role == UserRole.owner ? AppRoutes.shifts : AppRoutes.shiftsMine,
    'inventory' || 'inventory_items' =>
      role == UserRole.owner ? AppRoutes.inventory : AppRoutes.expenses,
    'attendance' || 'attendance_records' =>
      role == UserRole.owner ? AppRoutes.attendance : AppRoutes.attendanceMine,
    _ => null,
  };
}

bool _isKnownNotificationRoute(String route) {
  if (route.isEmpty || !route.startsWith('/')) return false;
  if (route.startsWith('/orders/')) return true;
  return const {
    AppRoutes.orders,
    AppRoutes.ordersMine,
    AppRoutes.requestReview,
    AppRoutes.requestsMine,
    AppRoutes.shifts,
    AppRoutes.shiftsMine,
    AppRoutes.inventory,
    AppRoutes.expenses,
    AppRoutes.attendance,
    AppRoutes.attendanceMine,
    AppRoutes.customers,
  }.contains(route);
}
