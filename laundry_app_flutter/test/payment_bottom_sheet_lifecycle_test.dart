import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:laundry_app_flutter/core/theme/app_theme.dart';
import 'package:laundry_app_flutter/core/widgets/app_snack_bar.dart';
import 'package:laundry_app_flutter/features/customers/presentation/customers_page.dart';
import 'package:laundry_app_flutter/features/orders/presentation/orders_page.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  tearDown(() {
    testerViewReset();
  });

  testWidgets(
    'pembayaran dari bottom sheet aman saat snackbar dan pindah tab',
    (tester) async {
      Intl.defaultLocale = 'id_ID';
      await initializeDateFormatting('id_ID');
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(430, 932);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(previewDataProvider.notifier);
      final state = container.read(previewDataProvider);
      notifier.createOrderWithItems(
        customerId: state.customers.first.id,
        items: [(serviceId: state.services.first.id, quantity: 3)],
        paidAmount: 0,
        paymentMethod: 'Tunai',
        employeeId: state.employees.first.id,
        note: '',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            scaffoldMessengerKey: appScaffoldMessengerKey,
            home: const _PaymentLifecycleHarness(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Pesanan'), findsWidgets);

      await tester.ensureVisible(find.text('Terima Pembayaran'));
      await tester.tap(find.text('Terima Pembayaran'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '5000',
      );
      await tester.ensureVisible(find.text('Simpan Pembayaran'));
      await tester.tap(find.text('Simpan Pembayaran'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => container.read(previewDataProvider).payments.length == 1,
      );
      expect(container.read(previewDataProvider).payments, hasLength(1));
      expect(
        container.read(previewDataProvider).cashTransactions,
        hasLength(1),
      );

      await tester.tap(find.text('Pelanggan'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomersPage), findsOneWidget);

      await tester.tap(find.text('Pesanan').last);
      await tester.pumpAndSettle();
      expect(find.byType(OrdersPage), findsOneWidget);

      await tester.ensureVisible(find.text('Terima Pembayaran'));
      await tester.tap(find.text('Terima Pembayaran'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '5000',
      );
      await tester.ensureVisible(find.text('Simpan Pembayaran'));
      await tester.tap(find.text('Simpan Pembayaran'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await _pumpUntil(
        tester,
        () => container.read(previewDataProvider).payments.length == 2,
      );
      expect(container.read(previewDataProvider).payments, hasLength(2));
      expect(
        container.read(previewDataProvider).cashTransactions,
        hasLength(2),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 20; i++) {
    if (condition()) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
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
