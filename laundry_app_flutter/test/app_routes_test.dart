import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/core/router/app_routes.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';

void main() {
  test('pengeluaran bisa dibuka owner dan karyawan', () {
    expect(AppRoutes.canOpen(AppRoutes.expenses, UserRole.owner), isTrue);
    expect(AppRoutes.canOpen(AppRoutes.expenses, UserRole.employee), isTrue);
  });

  test('kelola usaha hanya bisa dibuka owner', () {
    expect(
      AppRoutes.canOpen(AppRoutes.businessManagement, UserRole.owner),
      isTrue,
    );
    expect(
      AppRoutes.canOpen(AppRoutes.businessManagement, UserRole.employee),
      isFalse,
    );
  });

  test('fitur POS bisa dibuka owner dan karyawan yang sudah ditugaskan', () {
    expect(AppRoutes.canOpen(AppRoutes.posHome, UserRole.owner), isTrue);
    expect(AppRoutes.canOpen(AppRoutes.posCashier, UserRole.employee), isTrue);
  });

  test('halaman detail kembali ke induk yang sesuai peran', () {
    expect(
      AppRoutes.parentFor('/orders/order-1', UserRole.owner),
      AppRoutes.orders,
    );
    expect(
      AppRoutes.parentFor('/orders/order-1', UserRole.employee),
      AppRoutes.ordersMine,
    );
    expect(
      AppRoutes.parentFor(AppRoutes.leaveRequest, UserRole.employee),
      AppRoutes.requestsMine,
    );
    expect(
      AppRoutes.parentFor(AppRoutes.posProducts, UserRole.employee),
      AppRoutes.posHome,
    );
  });
}
