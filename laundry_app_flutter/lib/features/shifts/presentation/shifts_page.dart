import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

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
    final allShifts = ref.watch(
      previewDataProvider.select((state) => state.shifts),
    );
    final shifts = showMineOnly
        ? allShifts.where((shift) => shift.employeeId == 'employee-1').toList()
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
        child: shifts.isEmpty
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
                                  '${shift.startTime}-${shift.endTime}',
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
    final data = ref.read(previewDataProvider);
    var employeeId = existingShift?.employeeId ?? data.employees.first.id;
    var day = existingShift?.day ?? _days.first;
    final defaults = _defaultTimeForEmployee(employeeId);
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
                  for (final employee in data.employees)
                    DropdownMenuItem(
                      value: employee.id,
                      child: Text(employee.name),
                    ),
                ],
                onChanged: existingShift == null
                    ? (value) => setModalState(() {
                        employeeId = value ?? employeeId;
                        final defaults = _defaultTimeForEmployee(employeeId);
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
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    _ShiftInput(
                      employeeId: employeeId,
                      day: day,
                      startTime: start.text,
                      endTime: end.text,
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
        ref.read(previewDataProvider.notifier).deleteShift(result.deleteId!);
        showAppSnackBar('Shift berhasil dihapus.');
        return;
      }
      if (existingShift == null) {
        ref
            .read(previewDataProvider.notifier)
            .addShift(
              employeeId: result.employeeId,
              day: result.day,
              startTime: result.startTime,
              endTime: result.endTime,
            );
        showAppSnackBar('Shift berhasil ditambahkan.');
        return;
      }
      ref
          .read(previewDataProvider.notifier)
          .updateShift(
            id: existingShift.id,
            day: result.day,
            startTime: result.startTime,
            endTime: result.endTime,
          );
      showAppSnackBar('Shift berhasil diperbarui.');
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }

  (String, String) _defaultTimeForEmployee(String employeeId) {
    return switch (employeeId) {
      'employee-1' => ('06.00', '14.00'),
      'employee-2' => ('12.00', '20.00'),
      _ => ('06.00', '14.00'),
    };
  }
}

class _ShiftInput {
  const _ShiftInput({
    required this.employeeId,
    required this.day,
    required this.startTime,
    required this.endTime,
  }) : deleteId = null;

  const _ShiftInput.delete(String id)
    : employeeId = '',
      day = '',
      startTime = '',
      endTime = '',
      deleteId = id;

  final String employeeId;
  final String day;
  final String startTime;
  final String endTime;
  final String? deleteId;
}
