import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/errors/user_error_message.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: notifications.isEmpty
                ? null
                : () => ref
                      .read(notificationControllerProvider.notifier)
                      .markAllRead(),
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
                          await ref
                              .read(notificationControllerProvider.notifier)
                              .markRead(notification.id);
                          if (!context.mounted) return;
                          final route = _safeNotificationRoute(notification);
                          if (route != null) {
                            context.go(route);
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Hapus',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(notificationControllerProvider.notifier)
                              .delete(notification.id),
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

String? _safeNotificationRoute(PreviewNotification notification) {
  final route = notification.actionRoute.trim();
  if (route.isNotEmpty && route.startsWith('/')) return route;
  return switch (notification.referenceType.toLowerCase()) {
    'order' || 'orders' =>
      notification.referenceId == null
          ? AppRoutes.orders
          : '/orders/${notification.referenceId}',
    'employee_request' || 'employee_requests' => AppRoutes.requestsMine,
    'weekly_shift' || 'weekly_shifts' => AppRoutes.shiftsMine,
    'inventory' || 'inventory_items' => AppRoutes.inventory,
    'attendance' || 'attendance_records' => AppRoutes.attendanceMine,
    _ => null,
  };
}
