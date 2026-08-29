import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/failure.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/preview_data.dart';

class AttendanceRepository {
  AttendanceRepository({SupabaseClient? client})
    : _client = client ?? SupabaseService.maybeClient;

  final SupabaseClient? _client;
  bool get isOnline => _client != null;

  Future<List<PreviewAttendance>> fetch(String shopId) async {
    final rows = await _requireClient()
        .from('attendance_records')
        .select(
          'id, employee_id, employee_name, type, status, late_minutes, photo_path, created_at',
        )
        .eq('shop_id', shopId)
        .order('created_at', ascending: false)
        .limit(300);

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final created = DateTime.parse(row['created_at'] as String).toLocal();
      final key =
          '${row['employee_id']}|${created.year}-${created.month}-${created.day}';
      grouped.putIfAbsent(key, () => []).add(row);
    }

    final result = <PreviewAttendance>[];
    for (final entries in grouped.values) {
      final checkIn = entries
          .where((row) => row['type'] == 'CHECK_IN')
          .firstOrNull;
      if (checkIn == null) continue;
      final checkOut = entries
          .where((row) => row['type'] == 'CHECK_OUT')
          .firstOrNull;
      final checkInAt = DateTime.parse(
        checkIn['created_at'] as String,
      ).toLocal();
      final lateMinutes = (checkIn['late_minutes'] as num? ?? 0).toInt();
      result.add(
        PreviewAttendance(
          id: checkIn['id'] as String,
          employeeId: checkIn['employee_id'] as String,
          employeeName: (checkIn['employee_name'] ?? 'Karyawan') as String,
          date: DateTime(checkInAt.year, checkInAt.month, checkInAt.day),
          checkInAt: checkInAt,
          checkOutAt: checkOut == null
              ? null
              : DateTime.parse(checkOut['created_at'] as String).toLocal(),
          status: checkOut == null ? 'Masuk' : 'Selesai',
          attendanceStatus: lateMinutes > 60
              ? PreviewAttendanceStatus.severelyLate
              : lateMinutes > 0
              ? PreviewAttendanceStatus.late
              : PreviewAttendanceStatus.onTime,
          lateMinutes: lateMinutes,
        ),
      );
    }
    result.sort((first, second) => second.checkInAt.compareTo(first.checkInAt));
    return result;
  }

  Future<void> create({
    required String shopId,
    required String employeeId,
    required String employeeName,
    required bool isCheckOut,
    required int lateMinutes,
    required Uint8List photoBytes,
  }) async {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final photoPath = '$shopId/$employeeId/$timestamp.jpg';
    await _requireClient().storage
        .from('attendance-photos')
        .uploadBinary(
          photoPath,
          photoBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    try {
      await _requireClient().from('attendance_records').insert({
        'shop_id': shopId,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'type': isCheckOut ? 'CHECK_OUT' : 'CHECK_IN',
        'status': lateMinutes > 0 ? 'late' : 'on_time',
        'late_minutes': isCheckOut ? 0 : lateMinutes,
        'photo_path': photoPath,
      });
    } catch (_) {
      await _requireClient().storage.from('attendance-photos').remove([
        photoPath,
      ]);
      rethrow;
    }
  }

  RealtimeChannel subscribe({
    required String shopId,
    required void Function() onChanged,
  }) {
    return _requireClient()
        .channel('public:attendance_records:$shopId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance_records',
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
