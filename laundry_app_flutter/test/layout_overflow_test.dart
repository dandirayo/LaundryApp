import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/core/widgets/app_state_view.dart';
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
    expect(find.text('Diterima oleh: Ratna'), findsOneWidget);
    expect(find.text('Diproses oleh Belum ditugaskan'), findsNothing);

    await tester.tap(find.text('IDL-RATNA'));
    await tester.pumpAndSettle();
    expect(find.text('Diproses oleh Belum ditugaskan'), findsOneWidget);

    await tester.enterText(search, 'Pelanggan Yani');
    await tester.pump();
    expect(find.text('Pelanggan Yani'), findsWidgets);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Pesanan')),
      findsOneWidget,
    );
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
    ) {
      return PreviewOrder(
        id: id,
        orderNumber: 'IDL-$id',
        customerId: 'customer-1',
        customerNameSnapshot: customer,
        customerPhoneSnapshot: '',
        items: const [],
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
        order('RATNA', 'Destiana CS', 'employee-ratna', 'Ratna'),
        order('YANI', 'Pelanggan Yani', 'employee-yani', 'Yani'),
      ],
    );
  }
}
