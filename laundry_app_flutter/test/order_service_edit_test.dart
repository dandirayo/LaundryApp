import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/orders/presentation/order_detail_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('owner hanya mendapat pilihan edit layanan untuk item kiloan', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith(_OwnerAuth.new)],
    );
    addTearDown(container.dispose);
    final state = container.read(previewDataProvider);
    final kilo = state.services.singleWhere(
      (service) => service.id == 'service-cs-reguler',
    );
    final express = state.services.singleWhere(
      (service) => service.id == 'service-cs-express',
    );
    final unit = state.services.firstWhere(
      (service) => service.unit.toUpperCase() != 'KG',
    );
    final order = container
        .read(previewDataProvider.notifier)
        .createOrderWithItems(
          customerId: state.customers.first.id,
          items: [
            (serviceId: kilo.id, quantity: 5.1),
            (serviceId: unit.id, quantity: 1),
          ],
          paidAmount: 1000,
          paymentMethod: 'Tunai',
          employeeId: state.employees.first.id,
          note: '',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: OrderDetailPage(orderId: order.id),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Riwayat Pembayaran'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Edit tanggal pembayaran'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit pesanan'));
    await tester.pumpAndSettle();

    expect(find.text('Layanan Kiloan'), findsOneWidget);
    expect(
      find.byKey(ValueKey('kilo-service-${order.items.first.id}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('kilo-service-${order.items.last.id}')),
      findsNothing,
    );
    expect(find.textContaining('Berat tetap sama'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(ValueKey('kilo-service-${order.items.first.id}')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(express.name).last);
    await tester.pumpAndSettle();
    final saveButton = find.widgetWithText(FilledButton, 'Simpan Perubahan');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final updated = container
        .read(previewDataProvider)
        .orders
        .singleWhere((entry) => entry.id == order.id);
    expect(updated.items.first.serviceId, express.id);
    expect(updated.items.last.serviceId, unit.id);
  });
}

const _owner = AppUser(
  userId: 'owner',
  shopId: 'preview-shop-owner',
  name: 'Owner Idola',
  role: UserRole.owner,
  isActive: true,
);

class _OwnerAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(_owner);
}
