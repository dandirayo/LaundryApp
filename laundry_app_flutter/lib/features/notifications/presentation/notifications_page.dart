import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(
      previewDataProvider.select((state) => state.notifications),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          TextButton(
            onPressed: notifications.isEmpty
                ? null
                : () => ref
                      .read(previewDataProvider.notifier)
                      .markAllNotificationsRead(),
            child: const Text('Tandai semua'),
          ),
        ],
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: notifications.isEmpty
            ? const AppStateView.empty(
                title: 'Tidak ada notifikasi',
                message: 'Notifikasi realtime akan muncul di sini.',
              )
            : ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  return Card(
                    child: ListTile(
                      leading: Icon(
                        notification.isRead
                            ? Icons.notifications_none
                            : Icons.notifications_active,
                        color: notification.isRead
                            ? AppColors.secondaryText
                            : AppColors.warning,
                      ),
                      title: Text(
                        notification.title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${notification.message}\n${notification.createdAt.toIndonesianDate()} ${notification.createdAt.toIndonesianTime()}',
                      ),
                      isThreeLine: true,
                      onTap: () {
                        ref
                            .read(previewDataProvider.notifier)
                            .markNotificationRead(notification.id);
                        if (notification.actionRoute.isNotEmpty) {
                          context.go(notification.actionRoute);
                        }
                      },
                      trailing: IconButton(
                        tooltip: 'Hapus',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => ref
                            .read(previewDataProvider.notifier)
                            .deleteNotification(notification.id),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
