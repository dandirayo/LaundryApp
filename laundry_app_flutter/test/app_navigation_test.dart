import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:laundry_app_flutter/core/router/app_navigation.dart';
import 'package:laundry_app_flutter/core/theme/app_theme.dart';

void main() {
  testWidgets('halaman sekunder memakai stack dan kembali ke pembuka', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Home')),
            body: FilledButton(
              onPressed: () => AppNavigation.open(context, '/detail'),
              child: const Text('Buka detail'),
            ),
          ),
        ),
        GoRoute(
          path: '/detail',
          builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Detail')),
            body: const SizedBox.shrink(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka detail'));
    await tester.pumpAndSettle();

    expect(find.text('Detail'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
