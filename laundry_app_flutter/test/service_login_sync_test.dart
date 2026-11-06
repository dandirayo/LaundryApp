import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_app_flutter/core/errors/failure.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/orders/data/order_repository.dart';
import 'package:laundry_app_flutter/features/services/data/service_repository.dart';
import 'package:laundry_app_flutter/features/services/presentation/service_controller.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('login replaces preview services with server service IDs', () async {
    final repository = _Services();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        serviceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    final preview = await container.read(serviceControllerProvider.future);
    expect(preview.any((s) => s.id == 'service-cs-kilat'), isTrue);
    (container.read(authControllerProvider.notifier) as _Auth).login();
    final online = await container.read(serviceControllerProvider.future);
    expect(online.single.id, '11111111-1111-4111-8111-111111111111');
    expect(repository.requestedShop, 'shop-1');
  });

  test(
    'preview ID is rejected before sending unpaid order to server',
    () async {
      await expectLater(
        OrderRepository().create(
          shopId: 'shop-1',
          customerId: 'customer-1',
          employeeId: null,
          note: '',
          dueAt: DateTime(2026, 9, 5),
          paidAmount: 0,
          paymentMethod: 'Tunai',
          items: const [
            OrderCreateItem(
              serviceId: 'service-cs-kilat',
              serviceName: 'Cuci Setrika Kilat',
              category: 'Kiloan',
              unit: 'KG',
              quantity: 5,
              unitPrice: 12000,
              subtotal: 60000,
            ),
          ],
        ),
        throwsA(
          isA<Failure>().having((e) => e.code, 'code', 'service-not-synced'),
        ),
      );
    },
  );

  testWidgets('missed service Realtime event is recovered by polling', (
    tester,
  ) async {
    final repository = _Services();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_Auth.new),
        serviceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await container.read(authControllerProvider.future);
    (container.read(authControllerProvider.notifier) as _Auth).login();
    expect(
      (await container.read(serviceControllerProvider.future)).single.price,
      12000,
    );

    repository.price = 13000;
    // Simulate a dropped Realtime event. The periodic snapshot is authoritative.
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      container.read(serviceControllerProvider).value!.single.price,
      13000,
    );
    expect(repository.fetches, greaterThanOrEqualTo(2));
    container.dispose();
  });
}

class _Auth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.unauthenticated();
  void login() => state = const AsyncData(
    AuthSessionState.authenticated(
      AppUser(
        userId: 'ratna',
        shopId: 'shop-1',
        name: 'Ratna',
        role: UserRole.employee,
        isActive: true,
      ),
    ),
  );
}

class _Services extends ServiceRepository {
  String? requestedShop;
  int price = 12000;
  int fetches = 0;
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  @override
  bool get isOnline => true;
  @override
  Future<List<PreviewService>> fetch(String shopId) async {
    requestedShop = shopId;
    fetches++;
    return [
      PreviewService(
        id: '11111111-1111-4111-8111-111111111111',
        name: 'Cuci Setrika Kilat',
        category: 'Kiloan',
        unit: 'KG',
        price: price,
        estimatedHours: 12,
        isExpress: true,
        isActive: true,
      ),
    ];
  }

  @override
  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) => client.channel('test-$shopId');
  @override
  Future<void> removeChannel(RealtimeChannel channel) async {}
}
