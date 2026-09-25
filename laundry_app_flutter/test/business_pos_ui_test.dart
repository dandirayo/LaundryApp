import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/businesses/domain/business.dart';
import 'package:laundry_app_flutter/features/businesses/presentation/business_controller.dart';
import 'package:laundry_app_flutter/features/businesses/presentation/business_selector_page.dart';
import 'package:laundry_app_flutter/features/pos/domain/pos_models.dart';
import 'package:laundry_app_flutter/features/pos/presentation/pos_controller.dart';
import 'package:laundry_app_flutter/features/pos/presentation/pos_home_page.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('pemilih usaha menampilkan Laundry dan Es Teh aktif', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_OwnerAuth.new),
          businessControllerProvider.overrideWith(_BusinessList.new),
        ],
        child: const MaterialApp(home: BusinessSelectorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pilih Usaha'), findsOneWidget);
    expect(find.text('Idola Laundry'), findsOneWidget);
    expect(find.text('Es Teh Manis'), findsOneWidget);
    expect(find.text('AKTIF'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('beranda POS menampilkan status jualan dan omzet', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_OwnerAuth.new),
          businessControllerProvider.overrideWith(_SelectedTea.new),
          posControllerProvider.overrideWith(_PosSummary.new),
        ],
        child: const MaterialApp(home: PosHomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hari ini berjualan'), findsOneWidget);
    expect(find.text('Rp13.000'), findsWidgets);
    expect(find.text('Buka Kasir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _owner = AppUser(
  userId: 'owner',
  shopId: 'shop',
  name: 'Owner Idola',
  role: UserRole.owner,
  isActive: true,
);

const _laundry = Business(
  id: 'laundry',
  shopId: 'shop',
  ownerId: 'owner',
  name: 'Idola Laundry',
  kind: BusinessKind.laundry,
  isActive: true,
);

const _tea = Business(
  id: 'tea',
  shopId: 'shop',
  ownerId: 'owner',
  name: 'Es Teh Manis',
  kind: BusinessKind.beverage,
  isActive: true,
);

class _OwnerAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(_owner);
}

class _BusinessList extends BusinessController {
  @override
  Future<BusinessState> build() async => const BusinessState(
    businesses: [_laundry, _tea],
    assignees: [],
    assignments: {},
    isOnline: false,
  );
}

class _SelectedTea extends BusinessController {
  @override
  Future<BusinessState> build() async => const BusinessState(
    businesses: [_laundry, _tea],
    assignees: [],
    assignments: {},
    isOnline: false,
    selectedBusinessId: 'tea',
  );
}

class _PosSummary extends PosController {
  @override
  Future<PosState> build() async => PosState(
    businessId: 'tea',
    products: const [],
    todaySales: [
      PosSale(
        id: 'sale',
        businessId: 'tea',
        saleNumber: 'POS-1',
        total: 13000,
        paymentMethod: 'QRIS',
        createdAt: DateTime(2026, 9, 16, 9),
      ),
    ],
    isOpenToday: true,
    isOnline: false,
  );
}
