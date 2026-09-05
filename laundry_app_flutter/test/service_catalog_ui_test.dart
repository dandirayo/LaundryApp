import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/theme/app_theme.dart';
import 'package:laundry_app_flutter/features/orders/presentation/order_create_page.dart';
import 'package:laundry_app_flutter/features/services/presentation/services_page.dart';
import 'package:laundry_app_flutter/features/services/presentation/service_controller.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  testWidgets(
    'kontrol kiloan besar menerima 4,2 kg dan opsi pelanggan setia di bawah 3 kg',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OrderCreatePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final service = find.text('Cuci Setrika Reguler').first;
      await tester.ensureVisible(service);
      await tester.tap(service);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'kartu awal');

      final weightButton = find.widgetWithText(OutlinedButton, '3 KG');
      expect(weightButton, findsOneWidget);
      expect(tester.getSize(weightButton).height, greaterThanOrEqualTo(48));
      await tester.tap(weightButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah'),
        '4,2',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.widgetWithText(OutlinedButton, '4.2 KG'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'setelah 4,2 kg');

      await tester.tap(find.text('Aturan berat: minimal 3 kg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Izinkan di bawah 3 kg').last);
      await tester.pumpAndSettle();
      expect(find.text('Di bawah 3 kg diizinkan'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'menu di bawah minimum');
      await tester.tap(find.widgetWithText(OutlinedButton, '4.2 KG'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah'),
        '2,4',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.widgetWithText(OutlinedButton, '2.4 KG'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'setelah 2,4 kg');

      final submit = find.widgetWithText(FilledButton, 'SIMPAN & CETAK NOTA');
      expect(tester.getSize(submit).height, 50);
      expect(844 - tester.getBottomRight(submit).dy, lessThanOrEqualTo(12));
    },
  );

  testWidgets(
    'luas satuan bisa diedit menjadi 2,25 m2 tanpa pembulatan barang',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const OrderCreatePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satuan'));
      await tester.pumpAndSettle();
      final category = find.widgetWithText(ChoiceChip, 'Kain dan Gorden');
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Gorden'));
      await tester.tap(find.text('Gorden'));
      await tester.pumpAndSettle();
      final quantityButton = find.widgetWithText(OutlinedButton, '1 M2');
      await tester.ensureVisible(quantityButton);
      await tester.tap(quantityButton);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah'),
        '2,25',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('2.25 M2 x'), findsOneWidget);
      expect(find.textContaining('33.750'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('daftar harga menampilkan kategori utama lalu subkategori', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light(), home: const ServicesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kiloan'), findsOneWidget);
    expect(find.text('Satuan'), findsOneWidget);
    expect(find.text('Handuk'), findsNothing);
    await tester.tap(find.text('Satuan'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Handuk'), 180);
    await tester.tap(find.text('Handuk'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Handuk').last);
    await tester.tap(find.text('Handuk').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('10.000'), findsOneWidget);
    expect(find.textContaining('15.000'), findsOneWidget);
    expect(find.textContaining('20.000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'form satuan tidak menawarkan KG dan tambah offline langsung sinkron',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const ServicesPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Tambah layanan'));
      await tester.pumpAndSettle();
      final rootField = find.byType(DropdownButtonFormField<String>).first;
      await tester.ensureVisible(rootField);
      await tester.tap(rootField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Satuan').last);
      await tester.pumpAndSettle();
      final unitField = tester.widget<DropdownButtonFormField<String>>(
        find.byKey(const ValueKey('unit-Satuan')),
      );
      expect(unitField.initialValue, 'PIECE');
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(Form))).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await container
          .read(serviceControllerProvider.notifier)
          .add(
            name: 'Tas Baru',
            itemName: 'Tas Baru',
            sizeVariant: 'Kecil',
            materialVariant: '',
            category: 'Tas',
            unit: 'PIECE',
            price: 12000,
            estimatedHours: 72,
            isExpress: false,
          );
      final service = container
          .read(serviceControllerProvider)
          .requireValue
          .last;
      expect(service.name, 'Tas Baru Kecil');
      expect(service.effectiveGroup, 'Satuan');
      expect(service.effectiveCategory, 'Tas');
      expect(container.read(previewDataProvider).services.last.id, service.id);
    },
  );
}
