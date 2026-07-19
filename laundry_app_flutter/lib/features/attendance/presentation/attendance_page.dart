import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class AttendancePage extends ConsumerWidget {
  const AttendancePage({this.showMineOnly = false, super.key});

  final bool showMineOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (attendance: state.attendance, employees: state.employees),
      ),
    );
    final records = showMineOnly
        ? data.attendance
              .where((record) => record.employeeId == 'employee-1')
              .toList()
        : data.attendance;
    final currentEmployee = data.employees.first;

    return Scaffold(
      appBar: AppBar(
        title: Text(showMineOnly ? 'Absensi Saya' : 'Absensi Karyawan'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            if (showMineOnly) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Absensi Foto',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Foto wajib diambil dari kamera belakang sebelum absen tersimpan.',
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _confirmAttendance(
                                context,
                                ref,
                                currentEmployee,
                                isCheckOut: false,
                              ),
                              icon: const Icon(Icons.login),
                              label: const Text('Masuk'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmAttendance(
                                context,
                                ref,
                                currentEmployee,
                                isCheckOut: true,
                              ),
                              icon: const Icon(Icons.logout),
                              label: const Text('Keluar'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (records.isEmpty)
              const AppStateView.empty(
                title: 'Absensi belum ada',
                message: 'Record absensi akan tampil setelah absen masuk.',
              )
            else
              for (final record in records) ...[
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.fact_check_outlined,
                      color: _statusColor(record.attendanceStatus),
                    ),
                    title: Text(record.employeeName),
                    subtitle: Text(
                      '${record.date.toIndonesianDate()}\nShift ${record.shiftLabel.isEmpty ? '-' : record.shiftLabel} - Masuk ${record.checkInAt.toIndonesianTime()} - Keluar ${record.checkOutAt?.toIndonesianTime() ?? '-'}\n${_lateLabel(record)}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(record.attendanceStatus.label),
                      labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                      side: BorderSide.none,
                      backgroundColor: _statusColor(
                        record.attendanceStatus,
                      ).withValues(alpha: 0.16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAttendance(
    BuildContext context,
    WidgetRef ref,
    PreviewEmployee employee, {
    required bool isCheckOut,
  }) async {
    final confirmed = await showConfirmationDialog(
      context,
      title: isCheckOut ? 'Absen keluar?' : 'Absen masuk?',
      message:
          'Preview akan menyimpan timestamp server lokal dan foto simulasi untuk ${employee.name}.',
      confirmLabel: isCheckOut ? 'Keluar' : 'Masuk',
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 75,
      maxWidth: 1600,
    );
    if (photo == null || !context.mounted) {
      showAppSnackBar('Absen dibatalkan. Foto kamera belakang wajib diambil.');
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }

    try {
      ref
          .read(previewDataProvider.notifier)
          .addAttendance(
            employeeId: employee.id,
            employeeName: employee.name,
            isCheckOut: isCheckOut,
            photoPath: photo.path,
          );
      showAppSnackBar('Absen ${isCheckOut ? 'keluar' : 'masuk'} tersimpan.');
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }

  Color _statusColor(PreviewAttendanceStatus status) {
    return switch (status) {
      PreviewAttendanceStatus.onTime => AppColors.success,
      PreviewAttendanceStatus.late => AppColors.warning,
      PreviewAttendanceStatus.severelyLate ||
      PreviewAttendanceStatus.absent => AppColors.error,
      PreviewAttendanceStatus.leave ||
      PreviewAttendanceStatus.sick ||
      PreviewAttendanceStatus.permission => AppColors.primaryBlue,
    };
  }

  String _lateLabel(PreviewAttendance record) {
    if (record.lateMinutes <= 0) {
      return 'Tepat waktu';
    }
    final hours = record.lateMinutes ~/ 60;
    final minutes = record.lateMinutes % 60;
    final detail = hours > 0 ? '$hours jam $minutes menit' : '$minutes menit';
    return 'Terlambat $detail';
  }
}
