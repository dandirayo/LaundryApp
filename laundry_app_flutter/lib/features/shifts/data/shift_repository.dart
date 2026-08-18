import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class ShiftRepository {
  ShiftRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;

  bool get isOnline => _client != null;

  Future<List<PreviewShift>> fetchShifts({required String shopId}) async {
    final rows = await _requireClient()
        .from('weekly_shifts')
        .select(
          'id, employee_id, employee_name, day_of_week, start_time, end_time, is_day_off',
        )
        .eq('shop_id', shopId)
        .order('day_of_week')
        .order('employee_name');
    return [for (final row in rows) _fromMap(row)];
  }

  Future<void> createShift({
    required String shopId,
    required String employeeId,
    required String employeeName,
    required String day,
    required String startTime,
    required String endTime,
    required bool isDayOff,
  }) async {
    await _requireClient().from('weekly_shifts').upsert({
      'shop_id': shopId,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'day_of_week': _dayNumber(day),
      'start_time': _normalizeTime(startTime),
      'end_time': _normalizeTime(endTime),
      'is_day_off': isDayOff,
    }, onConflict: 'shop_id,employee_id,day_of_week');
  }

  Future<void> updateShift({
    required String shopId,
    required String id,
    required String employeeName,
    required String day,
    required String startTime,
    required String endTime,
    required bool isDayOff,
  }) async {
    await _requireClient()
        .from('weekly_shifts')
        .update({
          'employee_name': employeeName,
          'day_of_week': _dayNumber(day),
          'start_time': _normalizeTime(startTime),
          'end_time': _normalizeTime(endTime),
          'is_day_off': isDayOff,
        })
        .eq('id', id)
        .eq('shop_id', shopId);
  }

  Future<void> deleteShift({required String shopId, required String id}) async {
    await _requireClient()
        .from('weekly_shifts')
        .delete()
        .eq('id', id)
        .eq('shop_id', shopId);
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:weekly_shifts:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'weekly_shifts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'shop_id',
            value: shopId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) async {
    await _requireClient().removeChannel(channel);
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

PreviewShift _fromMap(Map<String, dynamic> map) {
  return PreviewShift(
    id: map['id'] as String,
    employeeId: map['employee_id'] as String,
    employeeName: (map['employee_name'] ?? 'Karyawan') as String,
    day: _dayName((map['day_of_week'] ?? 1) as int),
    startTime: _formatTime(map['start_time']?.toString() ?? '06:00'),
    endTime: _formatTime(map['end_time']?.toString() ?? '14:00'),
    isDayOff: (map['is_day_off'] ?? false) as bool,
  );
}

int _dayNumber(String day) =>
    const {
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 7,
    }[day] ??
    1;

String _dayName(int day) => const [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
][(day - 1).clamp(0, 6)];

String _normalizeTime(String value) {
  final parts = value.trim().replaceAll('.', ':').split(':');
  final hour = int.tryParse(parts.first) ?? 0;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

String _formatTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return value.replaceAll(':', '.');
  return '${parts[0].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}';
}
