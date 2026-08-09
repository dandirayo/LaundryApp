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
        .select(
          'id, name, phone, position, shift_start, shift_end, late_tolerance_minutes, is_active',
        )
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
          shiftStart: _formatTime(row['shift_start']?.toString() ?? '06:00'),
          shiftEnd: _formatTime(row['shift_end']?.toString() ?? '14:00'),
          lateToleranceMinutes: (row['late_tolerance_minutes'] ?? 120) as int,
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
    required String shiftStart,
    required String shiftEnd,
    required int lateToleranceMinutes,
    required bool isActive,
  }) async {
    final response = await _requireClient().functions.invoke(
      'create-employee-user',
      body: {
        'username': username.trim().toLowerCase(),
        'password': password,
        'name': name.trim(),
        'phone': phone.trim(),
        'position': position.trim(),
        'shift_start': _normalizeTime(shiftStart),
        'shift_end': _normalizeTime(shiftEnd),
        'late_tolerance_minutes': lateToleranceMinutes,
        'is_active': isActive,
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
    required String shiftStart,
    required String shiftEnd,
    required int lateToleranceMinutes,
    required bool isActive,
  }) async {
    final client = _requireClient();
    await client
        .from('employees')
        .update({
          'name': name.trim(),
          'phone': phone.trim(),
          'position': position.trim(),
          'shift_start': _normalizeTime(shiftStart),
          'shift_end': _normalizeTime(shiftEnd),
          'late_tolerance_minutes': lateToleranceMinutes,
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

  String _normalizeTime(String value) {
    final text = value.trim().replaceAll('.', ':');
    final parts = text.split(':');
    if (parts.length < 2) return text;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(String value) {
    final text = value.trim();
    if (text.isEmpty) return '06.00';
    final parts = text.split(':');
    if (parts.length < 2) return text.replaceAll(':', '.');
    return '${parts[0].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}';
  }
}
