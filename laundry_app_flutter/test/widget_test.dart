import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:laundry_app_flutter/core/widgets/feature_status_page.dart';

void main() {
  testWidgets('menampilkan state halaman fitur dengan penjelasan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FeatureStatusPage(
          title: 'Pesanan',
          phase: 'Phase 2',
          icon: Icons.receipt_long_outlined,
          description: 'Daftar pesanan akan tersinkron dengan Supabase.',
        ),
      ),
    );

    expect(find.text('Pesanan'), findsWidgets);
    expect(find.text('Phase 2'), findsOneWidget);
    expect(find.text('Belum ada data tersinkron'), findsOneWidget);
  });
}
