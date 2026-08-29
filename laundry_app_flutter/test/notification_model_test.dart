import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('notification copyWith preserves durable navigation metadata', () {
    final notification = PreviewNotification(
      id: 'notification-1',
      title: 'Request disetujui',
      message: 'Request Anda sudah disetujui.',
      type: 'REQUEST_APPROVED',
      createdAt: DateTime(2026),
      isRead: false,
      actionRoute: '/requests/me',
      targetProfileId: 'profile-1',
      referenceType: 'employee_request',
      referenceId: 'request-1',
    );

    final read = notification.copyWith(isRead: true);

    expect(read.isRead, isTrue);
    expect(read.targetProfileId, 'profile-1');
    expect(read.referenceType, 'employee_request');
    expect(read.referenceId, 'request-1');
  });

  test('unread count reflects mark-as-read model update', () {
    final notifications = [
      PreviewNotification(
        id: '1',
        title: 'A',
        message: '',
        type: 'INFO',
        createdAt: DateTime(2026),
        isRead: false,
        actionRoute: '',
      ),
      PreviewNotification(
        id: '2',
        title: 'B',
        message: '',
        type: 'INFO',
        createdAt: DateTime(2026),
        isRead: true,
        actionRoute: '',
      ),
    ];

    expect(notifications.where((item) => !item.isRead), hasLength(1));
    final marked = [
      notifications.first.copyWith(isRead: true),
      notifications.last,
    ];
    expect(marked.where((item) => !item.isRead), isEmpty);
  });
}
