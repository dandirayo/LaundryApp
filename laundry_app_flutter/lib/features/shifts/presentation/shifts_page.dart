import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_state_view.dart';
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

  Future<void> _showShiftSheet(BuildContext context, WidgetRef ref) async {
    final data = ref.read(previewDataProvider);
    var employeeId = data.employees.first.id;
    var day = _days.first;
    final start = TextEditingController(text: '08.00');
    final end = TextEditingController(text: '16.00');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AppBottomSheetBody(
            children: [
              const Text(
                'Tambah Shift',
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
                onChanged: (value) =>
                    setModalState(() => employeeId = value ?? employeeId),
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
                  try {
                    ref
                        .read(previewDataProvider.notifier)
                        .addShift(
                          employeeId: employeeId,
                          day: day,
                          startTime: start.text,
                          endTime: end.text,
                        );
                    Navigator.of(context).pop();
                  } on StateError catch (error) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.message)));
                  }
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Simpan'),
              ),
            ],
          ),
        );
      },
    );
    start.dispose();
    end.dispose();
  }
}
