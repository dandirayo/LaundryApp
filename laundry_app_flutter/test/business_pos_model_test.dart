import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/businesses/domain/business.dart';
import 'package:laundry_app_flutter/features/pos/presentation/pos_controller.dart';
import 'package:laundry_app_flutter/features/pos/domain/pos_models.dart';

void main() {
  test('business map membedakan Laundry dan POS minuman', () {
    final laundry = Business.fromMap({
      'id': 'laundry',
      'shop_id': 'shop',
      'owner_id': 'owner',
      'name': 'Idola Laundry',
      'kind': 'laundry',
      'status': 'active',
    });
    final tea = Business.fromMap({
      'id': 'tea',
      'shop_id': 'shop',
      'owner_id': 'owner',
      'name': 'Es Teh Manis',
      'kind': 'beverage',
      'status': 'inactive',
    });

    expect(laundry.kind, BusinessKind.laundry);
    expect(laundry.isActive, isTrue);
    expect(tea.kind, BusinessKind.beverage);
    expect(tea.isActive, isFalse);
  });

  test('ringkasan POS menjumlahkan omzet hari ini', () {
    final state = PosState(
      businessId: 'tea',
      products: const [],
      todaySales: [
        PosSale(
          id: '1',
          businessId: 'tea',
          saleNumber: 'POS-1',
          total: 12000,
          paymentMethod: 'Tunai',
          createdAt: DateTime(2026, 9, 16, 9),
        ),
        PosSale(
          id: '2',
          businessId: 'tea',
          saleNumber: 'POS-2',
          total: 8000,
          paymentMethod: 'QRIS',
          createdAt: DateTime(2026, 9, 16, 10),
        ),
      ],
      isOpenToday: true,
      isOnline: false,
    );

    expect(state.todayRevenue, 20000);
  });
}
