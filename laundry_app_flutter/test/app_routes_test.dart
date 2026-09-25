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
}
