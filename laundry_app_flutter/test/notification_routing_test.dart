import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/router/app_routes.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/notifications/presentation/notifications_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  PreviewNotification notification({
    String route = '',
    String referenceType = '',
    String? referenceId,
  }) => PreviewNotification(
    id: 'notification-1',
    title: 'Pembaruan',
    message: 'Data berubah.',
    type: 'INFO',
    createdAt: DateTime(2026, 9, 20),
    isRead: false,
    actionRoute: route,
    referenceType: referenceType,
    referenceId: referenceId,
  );

  test('routes request notifications according to the active role', () {
    final item = notification(referenceType: 'EMPLOYEE_REQUEST');

    expect(notificationRouteFor(item, UserRole.owner), AppRoutes.requestReview);
    expect(
      notificationRouteFor(item, UserRole.employee),
      AppRoutes.requestsMine,
    );
  });

  test('rejects an unknown stored route and uses durable order reference', () {
    final item = notification(
      route: '/route-lama-yang-tidak-ada',
      referenceType: 'ORDER_WORKFLOW',
      referenceId: 'order-1',
    );

    expect(notificationRouteFor(item, UserRole.employee), '/orders/order-1');
  });
}
