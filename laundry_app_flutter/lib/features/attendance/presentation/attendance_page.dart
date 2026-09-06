import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../employee_requests/domain/request_kind.dart';
import '../../employee_requests/presentation/employee_request_controller.dart';
import 'attendance_controller.dart';

class AttendancePage extends ConsumerWidget {
  const AttendancePage({this.showMineOnly = false, super.key});

  final bool showMineOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      previewDataProvider.select(
        (state) => (attendance: state.attendance, employees: state.employees),
      ),
    );
    final onlineAttendance = ref.watch(attendanceControllerProvider);
    final requestState = ref.watch(employeeRequestControllerProvider);
    final data = (
      attendance: onlineAttendance.value ?? preview.attendance,
      employees: preview.employees,
    );
    final user = ref.watch(authControllerProvider).value?.user;
    final currentEmployee = showMineOnly
        ? _resolveEmployee(data.employees, user)
        : data.employees.firstOrNull;
    final records = showMineOnly
        ? data.attendance
              .where((record) => record.employeeId == currentEmployee?.id)
              .toList()
        : data.attendance;
    final today = DateTime.now();
    final todayCheckIns = records.where(
      (record) =>
          record.date.year == today.year &&
          record.date.month == today.month &&
          record.date.day == today.day,
    );
    final latestCheckIn = todayCheckIns.isEmpty
        ? null
        : todayCheckIns.reduce(
            (first, second) =>
                first.checkInAt.isAfter(second.checkInAt) ? first : second,
          );
    final unlockRequested =
        requestState.value?.requests.any(
          (request) =>
              request.employeeId == currentEmployee?.id &&
              request.type == forgotAttendanceRequestType &&
              request.status == PreviewRequestStatus.pending &&
              (latestCheckIn == null ||
                  request.createdAt.isAfter(latestCheckIn.checkInAt)),
        ) ??
        false;
    final canCheckIn = latestCheckIn == null || unlockRequested;

    return Scaffold(
      appBar: AppBar(
        title: Text(showMineOnly ? 'Absensi Saya' : 'Absensi Karyawan'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            if (showMineOnly && currentEmployee == null) ...[
              const AppStateView.empty(
                title: 'Akun belum terhubung ke karyawan',
                message:
                    'Minta Owner cek Data Karyawan dan pastikan akun login ini tersambung ke data karyawan.',
              ),
              const SizedBox(height: 16),
            ],
            if (showMineOnly && currentEmployee != null) ...[
              _AttendanceActionCard(
                canCheckIn: canCheckIn,
                unlockRequested: unlockRequested,
                loading: requestState.isLoading,
                onCheckIn: () => _confirmAttendance(
                  context,
                  ref,
                  currentEmployee,
                  isCheckOut: false,
                ),
                onCheckOut: () => _confirmAttendance(
                  context,
                  ref,
                  currentEmployee,
                  isCheckOut: true,
                ),
                onForgot: () => _requestForgotAttendance(
                  context,
                  ref,
                  currentEmployee,
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
                _AttendanceRecordCard(
                  record: record,
                  statusColor: _statusColor(record.attendanceStatus),
                  lateLabel: _lateLabel(record),
                  showEmployeeName: !showMineOnly,
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _requestForgotAttendance(
    BuildContext context,
    WidgetRef ref,
    PreviewEmployee employee,
  ) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa Absen'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Alasan',
            hintText: 'Jelaskan alasan perlu membuka absen masuk kembali.',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.isEmpty) {
                showAppSnackBar('Alasan lupa absen wajib diisi.');
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !context.mounted) return;

    try {
      await ref
          .read(employeeRequestControllerProvider.notifier)
          .addRequest(
            type: forgotAttendanceRequestType,
            reason: reason,
            amount: 0,
            employeeId: employee.id,
            employeeName: employee.name,
          );
      if (context.mounted) {
        showAppSnackBar(
          'Alasan terkirim. Tombol absen masuk sudah dibuka kembali.',
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Permohonan lupa absen gagal dikirim. Coba lagi.',
          ),
        );
      }
    }
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
      showAppSnackBar(
        'Absensi dibatalkan. Anda wajib mengambil foto area kerja dengan kamera belakang sebagai bukti.',
      );
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }

    try {
      await ref
          .read(attendanceControllerProvider.notifier)
          .add(
            employee: employee,
            isCheckOut: isCheckOut,
            photoPath: photo.path,
            photoBytes: await photo.readAsBytes(),
          );
      showAppSnackBar(
        isCheckOut
            ? 'Absen keluar berhasil dicatat. Terima kasih atas kerja keras Anda hari ini!'
            : 'Absen masuk berhasil dicatat. Selamat bekerja dan melayani pelanggan!',
      );
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback: 'Absensi gagal disimpan. Periksa foto lalu coba lagi.',
          ),
        );
      }
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

class _AttendanceActionCard extends StatelessWidget {
  const _AttendanceActionCard({
    required this.canCheckIn,
    required this.unlockRequested,
    required this.loading,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onForgot,
  });

  final bool canCheckIn;
  final bool unlockRequested;
  final bool loading;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final VoidCallback onForgot;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FAFF), Color(0xFFFFFFFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.softBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fact_check_outlined,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Absensi hari ini',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 2),
                        Text('Foto area kerja diperlukan sebagai bukti absensi.'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canCheckIn ? onCheckIn : null,
                      icon: const Icon(Icons.login),
                      label: const Text('ABSEN MASUK'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCheckOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('ABSEN KELUAR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: loading ? null : onForgot,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(
                    unlockRequested
                        ? 'Absen masuk sudah dibuka kembali'
                        : 'Lupa absen? Kirim alasan ke Owner',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceRecordCard extends StatelessWidget {
  const _AttendanceRecordCard({
    required this.record,
    required this.statusColor,
    required this.lateLabel,
    required this.showEmployeeName,
  });

  final PreviewAttendance record;
  final Color statusColor;
  final String lateLabel;
  final bool showEmployeeName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showEmployeeName)
                        Text(
                          record.employeeName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                      Text(
                        record.date.toIndonesianDate(),
                        style: TextStyle(
                          color: showEmployeeName
                              ? AppColors.secondaryText
                              : AppColors.mainText,
                          fontWeight: showEmployeeName ? FontWeight.w600 : FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(record.attendanceStatus.label),
                  labelStyle: TextStyle(color: statusColor, fontWeight: FontWeight.w900),
                  side: BorderSide.none,
                  backgroundColor: statusColor.withValues(alpha: 0.14),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _AttendanceTimeBlock(
                    label: 'MASUK',
                    value: record.checkInAt.toIndonesianTime(),
                    icon: Icons.login,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _AttendanceTimeBlock(
                    label: 'KELUAR',
                    value: record.checkOutAt?.toIndonesianTime() ?? '--.--',
                    icon: Icons.logout,
                    color: record.checkOutAt == null
                        ? AppColors.secondaryText
                        : AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Shift ${record.shiftLabel.isEmpty ? '-' : record.shiftLabel} • $lateLabel',
              style: const TextStyle(color: AppColors.secondaryText, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTimeBlock extends StatelessWidget {
  const _AttendanceTimeBlock({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

PreviewEmployee? _resolveEmployee(
  List<PreviewEmployee> employees,
  AppUser? user,
) {
  final employeeId = user?.employeeId;
  final existing = employees
      .where((employee) => employee.id == employeeId)
      .firstOrNull;
  if (existing != null) return existing;
  if (employeeId != null && user?.userId.startsWith('preview-') != true) {
    return PreviewEmployee(
      id: employeeId,
      name: user?.name ?? 'Karyawan',
      phone: user?.phone ?? '',
      position: 'Karyawan',
      isActive: true,
    );
  }
  return null;
}
