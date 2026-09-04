import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/cashbook/data/cashbook_repository.dart';
import 'package:laundry_app_flutter/features/cashbook/presentation/cashbook_controller.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';

void main() {
  test('Buku Kas switches from preview to server after login', () async {
    final repository = _CashRepository();
    final container = _container(repository);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);
    expect(
      (await container.read(cashbookControllerProvider.future)).isOnline,
      isFalse,
    );
    (container.read(authControllerProvider.notifier) as _Auth).login();
    final online = await container.read(cashbookControllerProvider.future);
    expect(online.isOnline, isTrue);
    expect(online.transactions.single.amount, 20000);
    expect(repository.subscriptions, 1);

    repository.fail = true;
    await container.read(cashbookControllerProvider.notifier).refresh();
    final failed = container.read(cashbookControllerProvider);
    expect(failed.value!.syncFailed, isTrue);
    expect(failed.value!.transactions.single.amount, 20000);
  });

  testWidgets('missed Realtime event is recovered by periodic refresh', (
    tester,
  ) async {
    final repository = _CashRepository();
    final container = _container(repository);
    await container.read(authControllerProvider.future);
    (container.read(authControllerProvider.notifier) as _Auth).login();
    await container.read(cashbookControllerProvider.future);
    repository.amount = 35000;
    // No Realtime callback is delivered: the periodic reconciliation must fetch it.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      container
          .read(cashbookControllerProvider)
          .value!
          .transactions
          .single
          .amount,
      35000,
    );
    container.dispose();
  });
}

ProviderContainer _container(_CashRepository repository) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_Auth.new),
    cashbookRepositoryProvider.overrideWithValue(repository),
  ],
);

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

class _CashRepository extends CashbookRepository {
  int amount = 20000;
  int subscriptions = 0;
  bool fail = false;
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  @override
  bool get isOnline => true;

  @override
  Future<List<PreviewCashTransaction>> fetch({required String shopId}) async {
    if (fail) throw StateError('Connection interrupted');
    return [
      PreviewCashTransaction(
        id: 'cash-1',
        referenceId: 'payment-1',
        referenceType: 'PAYMENT',
        type: 'IN',
        category: 'Laundry',
        description: 'Pembayaran',
        amount: amount,
        method: 'Tunai',
        createdAt: DateTime(2026, 9, 4),
      ),
    ];
  }

  @override
  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    subscriptions++;
    return client.channel('test-$shopId');
  }

  @override
  Future<void> removeChannel(RealtimeChannel channel) async {}
}
