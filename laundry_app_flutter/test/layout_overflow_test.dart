import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/widgets/app_state_view.dart';
import 'package:laundry_app_flutter/features/orders/presentation/orders_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
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

  testWidgets('Pesanan Saya kosong tidak overflow di layar 320x568', (
    tester,
  ) async {
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
          home: const OrdersPage(showMineOnly: true),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Pesanan Saya'), findsOneWidget);
    expect(find.text('Tambah pesanan'), findsOneWidget);
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
