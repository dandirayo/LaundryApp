import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class CreatedEmployeeAccount {
  const CreatedEmployeeAccount({
    required this.employeeId,
    required this.username,
  });

  final String employeeId;
  final String username;
}

class EmployeeRepository {
  EmployeeRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<PreviewEmployee>> fetchEmployees() async {
    final client = _requireClient();
    final employeeRows = await client
        .from('employees')
        .select('id, name, phone, position, is_active')
        .eq('role', 'EMPLOYEE')
        .order('name');
    final profileRows = await client
        .from('profiles')
        .select('employee_id, username')
        .eq('role', 'EMPLOYEE');

    final usernames = <String, String>{
      for (final row in profileRows)
        if (row['employee_id'] != null)
          row['employee_id'] as String: (row['username'] ?? '') as String,
    };

    return [
      for (final row in employeeRows)
        PreviewEmployee(
          id: row['id'] as String,
          name: (row['name'] ?? '') as String,
          phone: (row['phone'] ?? '') as String,
          position: (row['position'] ?? 'Operator') as String,
          isActive: (row['is_active'] ?? true) as bool,
          username: usernames[row['id']] ?? '',
        ),
    ];
  }

  Future<CreatedEmployeeAccount> createAccount({
    required String username,
    required String password,
    required String name,
    required String phone,
    required String position,
  }) async {
    final response = await _requireClient().functions.invoke(
      'create-employee-user',
      body: {
        'username': username.trim().toLowerCase(),
        'password': password,
        'name': name.trim(),
        'phone': phone.trim(),
        'position': position.trim(),
      },
    );
    final data = response.data;
    if (response.status < 200 || response.status >= 300 || data is! Map) {
      final message = data is Map ? data['error']?.toString() : null;
      throw Failure(
        code: 'employee-account-create-failed',
        message: message ?? 'Akun karyawan gagal dibuat di Supabase.',
      );
    }
    return CreatedEmployeeAccount(
      employeeId: data['employee_id'] as String,
      username: data['username'] as String,
    );
  }

  Future<void> updateEmployee({
    required String id,
    required String name,
    required String phone,
    required String position,
    required bool isActive,
  }) async {
    final client = _requireClient();
    await client
        .from('employees')
        .update({
          'name': name.trim(),
          'phone': phone.trim(),
          'position': position.trim(),
          'is_active': isActive,
        })
        .eq('id', id);
    await client
        .from('profiles')
        .update({
          'full_name': name.trim(),
          'phone': phone.trim(),
          'is_active': isActive,
        })
        .eq('employee_id', id);
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw const Failure(
        code: 'supabase-not-configured',
        message: 'Supabase belum dikonfigurasi.',
      );
    }
    return client;
  }
}
