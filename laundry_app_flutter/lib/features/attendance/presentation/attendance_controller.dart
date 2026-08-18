import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/attendance_repository.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(),
);

final attendanceControllerProvider =
    AsyncNotifierProvider<AttendanceController, List<PreviewAttendance>>(
      AttendanceController.new,
    );

class AttendanceController extends AsyncNotifier<List<PreviewAttendance>> {
  late AttendanceRepository _repository;

  @override
  Future<List<PreviewAttendance>> build() async {
    _repository = ref.watch(attendanceRepositoryProvider);
    return _load();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }

  Future<void> add({
    required PreviewEmployee employee,
    required bool isCheckOut,
    required String photoPath,
    required Uint8List photoBytes,
  }) async {
    final user = ref.read(authControllerProvider).value?.user;
    if (_repository.isOnline &&
        user != null &&
        !user.shopId.startsWith('preview-shop')) {
      await _repository.create(
        shopId: user.shopId,
        employeeId: employee.id,
        employeeName: employee.name,
        isCheckOut: isCheckOut,
        lateMinutes: isCheckOut ? 0 : _lateMinutes(employee),
        photoBytes: photoBytes,
      );
      await refresh();
    } else {
      ref
          .read(previewDataProvider.notifier)
          .addAttendance(
            employeeId: employee.id,
            employeeName: employee.name,
            isCheckOut: isCheckOut,
            photoPath: photoPath,
          );
    }
  }

  Future<List<PreviewAttendance>> _load() async {
    final user = ref.read(authControllerProvider).value?.user;
    if (!_repository.isOnline ||
        user == null ||
        user.shopId.startsWith('preview-shop')) {
      return ref.read(previewDataProvider).attendance;
    }
    return _repository.fetch(user.shopId);
  }

  int _lateMinutes(PreviewEmployee employee) {
    final parts = employee.shiftStart.replaceAll('.', ':').split(':');
    final now = DateTime.now();
    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts.first) ?? 6,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    ).add(Duration(minutes: employee.lateToleranceMinutes));
    return now.isAfter(scheduled) ? now.difference(scheduled).inMinutes : 0;
  }
}
