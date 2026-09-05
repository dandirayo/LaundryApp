import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laundry_app_flutter/features/auth/domain/app_user.dart';
import 'package:laundry_app_flutter/features/auth/domain/user_role.dart';
import 'package:laundry_app_flutter/features/auth/presentation/auth_controller.dart';
import 'package:laundry_app_flutter/features/employee_requests/data/employee_request_repository.dart';
import 'package:laundry_app_flutter/features/employee_requests/presentation/employee_request_controller.dart';
import 'package:laundry_app_flutter/shared/preview_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets('persetujuan yang melewatkan Realtime tetap tersinkron berkala', (
    tester,
  ) async {
    final repository = _RequestRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_EmployeeAuth.new),
        employeeRequestRepositoryProvider.overrideWithValue(repository),
      ],
    );
    await container.read(authControllerProvider.future);
    final initial = await container.read(
      employeeRequestControllerProvider.future,
    );
    expect(initial.requests.single.status, PreviewRequestStatus.pending);

    repository.status = PreviewRequestStatus.approved;
    // Simulasikan event Realtime terlewat di HP karyawan.
    await tester.pump(const Duration(seconds: 15));
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      container
          .read(employeeRequestControllerProvider)
          .value!
          .requests
          .single
          .status,
      PreviewRequestStatus.approved,
    );
    container.dispose();
  });
}

class _EmployeeAuth extends AuthController {
  @override
  Future<AuthSessionState> build() async =>
      const AuthSessionState.authenticated(
        AppUser(
          userId: 'ratna-user',
          shopId: 'shop-1',
          employeeId: 'employee-1',
          name: 'Ratna',
          role: UserRole.employee,
          isActive: true,
        ),
      );
}

class _RequestRepository extends EmployeeRequestRepository {
  PreviewRequestStatus status = PreviewRequestStatus.pending;
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  @override
  bool get isOnline => true;

  @override
  Future<List<PreviewEmployeeRequest>> fetchRequests({
    required String shopId,
  }) async => [
    PreviewEmployeeRequest(
      id: 'request-1',
      employeeId: 'employee-1',
      employeeName: 'Ratna',
      type: 'Request Izin',
      reason: 'Keperluan pribadi',
      amount: 0,
      status: status,
      reviewNote: '',
      createdAt: DateTime(2026, 9, 5),
    ),
  ];

  @override
  RealtimeChannel subscribeToRequests({
    required String shopId,
    required void Function() onChanged,
  }) => client.channel('request-$shopId');

  @override
  Future<void> removeSubscription(RealtimeChannel channel) async {}
}
