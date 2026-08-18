import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../employees/data/employee_repository.dart';
import 'shift_controller.dart';

final shiftEmployeesProvider = FutureProvider<List<PreviewEmployee>>((
  ref,
) async {
  final fallback = ref.read(previewDataProvider).employees;
  final user = ref.watch(authControllerProvider).value?.user;
  final repository = EmployeeRepository();
  if (!repository.isOnline ||
      user == null ||
      user.shopId.startsWith('preview-shop')) {
    return fallback;
  }
  final employees = await repository.fetchEmployees();
  ref.read(previewDataProvider.notifier).replaceEmployees(employees);
  return employees;
});

class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({this.showMineOnly = false, super.key});

  final bool showMineOnly;

  static const _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewShifts = ref.watch(
      previewDataProvider.select((state) => state.shifts),
    );
    final shiftState = ref.watch(shiftControllerProvider);
    final allShifts = shiftState.value?.shifts ?? previewShifts;
    final employeeId = ref
        .watch(authControllerProvider)
        .value
        ?.user
        ?.employeeId;
    final shifts = showMineOnly
        ? allShifts.where((shift) => shift.employeeId == employeeId).toList()
        : allShifts;

    return Scaffold(
      appBar: AppBar(
        title: Text(showMineOnly ? 'Jadwal Saya' : 'Jadwal Shift'),
        actions: [
          if (!showMineOnly)
            IconButton(
              tooltip: 'Tambah shift',
              onPressed: () => _showShiftSheet(context, ref),
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      floatingActionButton: showMineOnly || shifts.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showShiftSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Shift'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          showMineOnly || shifts.isEmpty ? 24 : 96,
        ),
        child: shiftState.isLoading && shifts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : shifts.isEmpty
            ? AppStateView.empty(
                title: 'Jadwal belum ada',
                message: 'Tambahkan shift mingguan untuk karyawan.',
                actionLabel: showMineOnly ? null : 'Tambah shift',
                onAction: showMineOnly
                    ? null
                    : () => _showShiftSheet(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _days.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final day = _days[index];
                  final dayShifts = shifts
                      .where((shift) => shift.day == day)
                      .toList();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          if (dayShifts.isEmpty)
                            const Text('Belum ada jadwal.')
                          else
                            for (final shift in dayShifts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.schedule),
                                title: Text(shift.employeeName),
                                subtitle: Text(
                                  shift.isDayOff
                                      ? 'Libur'
                                      : '${shift.startTime}-${shift.endTime}',
                                ),
                                trailing: showMineOnly
                                    ? null
                                    : const Icon(Icons.edit_outlined),
                                onTap: showMineOnly
                                    ? null
                                    : () => _showShiftSheet(
                                        context,
                                        ref,
                                        existingShift: shift,
                                      ),
                              ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showShiftSheet(
    BuildContext context,
    WidgetRef ref, {
    PreviewShift? existingShift,
  }) async {
    final employees =
        ref.read(shiftEmployeesProvider).value ??
        ref.read(previewDataProvider).employees;
    if (employees.isEmpty) {
      showAppSnackBar('Tambahkan karyawan dulu sebelum membuat shift.');
      return;
    }
    var employeeId = existingShift?.employeeId ?? employees.first.id;
    var day = existingShift?.day ?? _days.first;
    var isDayOff = existingShift?.isDayOff ?? false;
    final defaults = _defaultTimeForEmployee(employeeId, employees);
    final start = TextEditingController(
      text: existingShift?.startTime ?? defaults.$1,
    );
    final end = TextEditingController(
      text: existingShift?.endTime ?? defaults.$2,
    );
    final result = await showAppModalBottomSheet<_ShiftInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AppBottomSheetBody(
            children: [
              const Text(
                'Atur Shift',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: employeeId,
                items: [
                  for (final employee in employees)
                    DropdownMenuItem(
                      value: employee.id,
                      child: Text(employee.name),
                    ),
                ],
                onChanged: existingShift == null
                    ? (value) => setModalState(() {
                        employeeId = value ?? employeeId;
                        final defaults = _defaultTimeForEmployee(
                          employeeId,
                          employees,
                        );
                        start.text = defaults.$1;
                        end.text = defaults.$2;
                      })
                    : null,
                decoration: const InputDecoration(labelText: 'Karyawan'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: day,
                items: [
                  for (final item in _days)
                    DropdownMenuItem(value: item, child: Text(item)),
                ],
                onChanged: (value) => setModalState(() => day = value ?? day),
                decoration: const InputDecoration(labelText: 'Hari'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hari libur'),
                value: isDayOff,
                onChanged: (value) => setModalState(() => isDayOff = value),
              ),
              if (!isDayOff) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: start,
                        decoration: const InputDecoration(labelText: 'Mulai'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: end,
                        decoration: const InputDecoration(labelText: 'Selesai'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    _ShiftInput(
                      employeeId: employeeId,
                      day: day,
                      startTime: start.text,
                      endTime: end.text,
                      isDayOff: isDayOff,
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
              if (existingShift != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(_ShiftInput.delete(existingShift.id)),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus shift'),
                ),
              ],
            ],
          ),
        );
      },
    );
    start.dispose();
    end.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    try {
      if (result.deleteId != null) {
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Hapus shift?',
          message:
              'Shift ini akan dihapus dari jadwal. Absensi berikutnya akan mengikuti jadwal yang tersisa.',
          confirmLabel: 'Hapus',
          isDestructive: true,
        );
        if (!confirmed || !context.mounted) {
          return;
        }
        await ref
            .read(shiftControllerProvider.notifier)
            .delete(result.deleteId!);
        showAppSnackBar('Shift berhasil dihapus.');
        return;
      }
      if (existingShift == null) {
        final employee = employees.firstWhere(
          (item) => item.id == result.employeeId,
        );
        await ref
            .read(shiftControllerProvider.notifier)
            .save(
              employeeId: result.employeeId,
              employeeName: employee.name,
              day: result.day,
              startTime: result.startTime,
              endTime: result.endTime,
              isDayOff: result.isDayOff,
            );
        showAppSnackBar('Shift berhasil ditambahkan.');
        return;
      }
      await ref
          .read(shiftControllerProvider.notifier)
          .save(
            id: existingShift.id,
            employeeId: existingShift.employeeId,
            employeeName: existingShift.employeeName,
            day: result.day,
            startTime: result.startTime,
            endTime: result.endTime,
            isDayOff: result.isDayOff,
          );
      showAppSnackBar('Shift berhasil diperbarui.');
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }

  (String, String) _defaultTimeForEmployee(
    String employeeId,
    List<PreviewEmployee> employees,
  ) {
    final employee = employees
        .where((item) => item.id == employeeId)
        .firstOrNull;
    return (employee?.shiftStart ?? '06.00', employee?.shiftEnd ?? '14.00');
  }
}

class _ShiftInput {
  const _ShiftInput({
    required this.employeeId,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.isDayOff,
  }) : deleteId = null;

  const _ShiftInput.delete(String id)
    : employeeId = '',
      day = '',
      startTime = '',
      endTime = '',
      isDayOff = false,
      deleteId = id;

  final String employeeId;
  final String day;
  final String startTime;
  final String endTime;
  final bool isDayOff;
  final String? deleteId;
}
