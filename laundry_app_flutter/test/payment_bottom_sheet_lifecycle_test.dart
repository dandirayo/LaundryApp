import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/widgets/app_snack_bar.dart';
import 'package:laundry_app_flutter/features/customers/presentation/customers_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/orders_page.dart';

void main() {
  tearDown(() {
    testerViewReset();
  });

  testWidgets(
    'pembayaran dari bottom sheet aman saat snackbar dan pindah tab',
    (tester) async {
      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            scaffoldMessengerKey: appScaffoldMessengerKey,
            home: const _PaymentLifecycleHarness(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Pesanan'), findsWidgets);

      await tester.ensureVisible(find.text('Bayar'));
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, '5000');
      await tester.tap(find.text('Simpan Pembayaran'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Pembayaran masuk Buku Kas.'), findsOneWidget);

      await tester.tap(find.text('Pelanggan'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersPage), findsOneWidget);

      await tester.tap(find.text('Pesanan').last);
      await tester.pumpAndSettle();
      expect(find.byType(OrdersPage), findsOneWidget);

      await tester.ensureVisible(find.text('Bayar'));
      await tester.tap(find.text('Bayar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Pembayaran'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Pembayaran masuk Buku Kas.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(flutterErrors, isEmpty);
    },
  );
}

void testerViewReset() {
  final view =
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
  view.resetPhysicalSize();
  view.resetDevicePixelRatio();
}

class _PaymentLifecycleHarness extends StatefulWidget {
  const _PaymentLifecycleHarness();

  @override
  State<_PaymentLifecycleHarness> createState() =>
      _PaymentLifecycleHarnessState();
}

class _PaymentLifecycleHarnessState extends State<_PaymentLifecycleHarness> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [OrdersPage(), CustomersPage()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pesanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pelanggan',
          ),
        ],
      ),
    );
  }
}
