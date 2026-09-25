import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/core/widgets/app_state_view.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/cashbook/presentation/cashbook_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/orders_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));
  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('empty state tetap aman pada layar pendek dan text scale besar', (
    tester,
  ) async {
    await _setSmallPhone(tester);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: AppStateView.empty(
              title: 'Pesanan belum ada',
              message:
                  'Buat pesanan baru lewat aksi cepat. Data offline tersimpan lokal.',
              actionLabel: 'Tambah pesanan',
              onAction: null,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('Pesanan kosong tidak overflow di layar 320x568', (tester) async {
    await _setSmallPhone(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          previewDataProvider.overrideWith(_EmptyOrdersPreviewController.new),
        ],
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            );
          },
          home: const OrdersPage(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pesanan'), findsWidgets);
    expect(find.text('Buat Pesanan Baru'), findsOneWidget);
  });

  testWidgets('ringkasan Buku Kas tidak menyempitkan judul panjang', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_CashbookAuth.new),
          previewDataProvider.overrideWith(_CashbookPreviewController.new),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const CashbookPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();

    expect(find.text('Pendapatan terbesar'), findsOneWidget);
    expect(
      find.text('Pembayaran IDL-20260920-0524B6 (Rp32.000)'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('daftar Pesanan menampilkan order Ratna dan Yani', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          previewDataProvider.overrideWith(_SharedOrdersPreviewController.new),
        ],
        child: MaterialApp(
          theme: ThemeData(splashFactory: InkRipple.splashFactory),
          home: const OrdersPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    await tester.enterText(search, 'Destiana CS');
    await tester.pump();
    expect(find.text('Destiana CS'), findsWidgets);
    expect(find.text('Semua kecepatan'), findsOneWidget);
    expect(find.text('Express'), findsOneWidget);
    expect(find.text('Kilat'), findsOneWidget);
    expect(find.text('Diterima oleh: Ratna'), findsNothing);
    expect(find.text('Diproses oleh Belum ditugaskan'), findsNothing);

    await tester.tap(find.text('IDL-RATNA'));
    await tester.pumpAndSettle();
    expect(find.text('Diterima oleh: Ratna'), findsOneWidget);
    expect(find.text('Ketuk rincian untuk detail lengkap'), findsOneWidget);
    expect(find.text('Pesanan Selesai'), findsOneWidget);

    await tester.enterText(search, 'Pelanggan Yani');
    await tester.pump();
    expect(find.text('Pelanggan Yani'), findsWidgets);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Pesanan')),
      findsOneWidget,
    );

    await tester.enterText(search, '');
    final expressChip = find.ancestor(
      of: find.text('Express'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(expressChip);
    await tester.tap(expressChip);
    await tester.pump();
    expect(find.text('IDL-RATNA'), findsOneWidget);
    expect(find.text('IDL-YANI'), findsNothing);

    final kilatChip = find.ancestor(
      of: find.text('Kilat'),
      matching: find.byType(ChoiceChip),
    );
    await tester.ensureVisible(kilatChip);
    await tester.tap(kilatChip);
    await tester.pump();
    expect(find.text('IDL-RATNA'), findsNothing);
    expect(find.text('IDL-YANI'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSmallPhone(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 568);
}

class _EmptyOrdersPreviewController extends PreviewDataController {
  @override
  PreviewDataState build() {
    return super.build().copyWith(orders: const []);
  }
}

class _SharedOrdersPreviewController extends PreviewDataController {
  @override
  PreviewDataState build() {
    final original = super.build();
    final now = DateTime(2026, 9, 2, 12);
    PreviewOrder order(
      String id,
      String customer,
      String employeeId,
      String receiverName,
      String serviceName,
    ) {
      return PreviewOrder(
        id: id,
        orderNumber: 'IDL-$id',
        customerId: 'customer-1',
        customerNameSnapshot: customer,
        customerPhoneSnapshot: '',
        items: [
          PreviewOrderItem(
            id: 'item-$id',
            serviceId: 'service-$id',
            serviceNameSnapshot: serviceName,
            unit: 'PCS',
            quantity: 1,
            price: 85000,
            total: 85000,
          ),
        ],
        totalPrice: 85000,
        paidAmount: 0,
        orderStatus: PreviewOrderStatus.received,
        paymentStatus: PreviewPaymentStatus.unpaid,
        receivedAt: now,
        dueAt: now.add(const Duration(days: 3)),
        assignedEmployeeId: employeeId,
        receivedByName: receiverName,
        note: '',
      );
    }

    return original.copyWith(
      orders: [
        order(
          'RATNA',
          'Destiana CS',
          'employee-ratna',
          'Ratna',
          'Cuci Setrika Express',
        ),
        order(
          'YANI',
          'Pelanggan Yani',
          'employee-yani',
          'Yani',
          'Cuci Kering Kilat',
        ),
      ],
    );
  }
}

class _CashbookAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(
        AppUser(
          userId: 'owner-1',
          shopId: 'preview-shop-owner',
          name: 'Owner',
          role: UserRole.owner,
          isActive: true,
        ),
      );
}

class _CashbookPreviewController extends PreviewDataController {
  @override
  PreviewDataState build() {
    return super.build().copyWith(
      cashTransactions: [
        PreviewCashTransaction(
          id: 'cash-long-summary',
          referenceId: 'order-1',
          referenceType: 'PAYMENT',
          type: 'IN',
          category: 'Laundry',
          description: 'Pembayaran IDL-20260920-0524B6',
          amount: 32000,
          method: 'Tunai',
          createdAt: DateTime.now(),
        ),
      ],
    );
  }
}
