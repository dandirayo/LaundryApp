import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class EmployeesPage extends ConsumerWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employees = ref.watch(
      previewDataProvider.select((state) => state.employees),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Karyawan'),
        actions: [
          IconButton(
            tooltip: 'Tambah karyawan',
            onPressed: () => _showEmployeeSheet(context, ref: ref),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: employees.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showEmployeeSheet(context, ref: ref),
              icon: const Icon(Icons.add),
              label: const Text('Karyawan'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, employees.isEmpty ? 24 : 96),
        child: employees.isEmpty
            ? const AppStateView.empty(
                title: 'Karyawan belum ada',
                message: 'Tambahkan data karyawan untuk shift dan absensi.',
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: employees.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final employee = employees[index];
                  return Card(
                    child: ListTile(
                      onTap: () => _showEmployeeSheet(
                        context,
                        ref: ref,
                        employee: employee,
                      ),
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(employee.name),
                      subtitle: Text(
                        '${employee.position} - ${employee.phone}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(employee.isActive ? 'Aktif' : 'Nonaktif'),
                          IconButton(
                            tooltip: 'Edit karyawan',
                            onPressed: () => _showEmployeeSheet(
                              context,
                              ref: ref,
                              employee: employee,
                            ),
                            icon: const Icon(Icons.edit_outlined),
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

  Future<void> _showEmployeeSheet(
    BuildContext context, {
    required WidgetRef ref,
    PreviewEmployee? employee,
  }) async {
    final isEditing = employee != null;
    final name = TextEditingController(text: employee?.name ?? '');
    final phone = TextEditingController(text: employee?.phone ?? '');
    final position = TextEditingController(
      text: employee?.position ?? 'Operator',
    );
    var isActive = employee?.isActive ?? true;
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_EmployeeInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Form(
            key: formKey,
            child: AppBottomSheetBody(
              children: [
                Text(
                  isEditing ? 'Edit Karyawan' : 'Tambah Karyawan',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Telepon'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Posisi'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Status aktif'),
                  subtitle: Text(
                    isActive
                        ? 'Karyawan bisa dipilih untuk operasional.'
                        : 'Karyawan disimpan sebagai nonaktif.',
                  ),
                  value: isActive,
                  onChanged: (value) => setModalState(() => isActive = value),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }
                    Navigator.of(context).pop(
                      _EmployeeInput(
                        name: name.text,
                        phone: phone.text,
                        position: position.text,
                        isActive: isActive,
                      ),
                    );
                  },
                  icon: Icon(
                    isEditing
                        ? Icons.check_circle_outline
                        : Icons.save_outlined,
                  ),
                  label: Text(isEditing ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ],
            ),
          );
        },
      ),
    );
    name.dispose();
    phone.dispose();
    position.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    try {
      final notifier = ref.read(previewDataProvider.notifier);
      if (isEditing) {
        notifier.updateEmployee(
          id: employee.id,
          name: result.name,
          phone: result.phone,
          position: result.position,
          isActive: result.isActive,
        );
      } else {
        notifier.addEmployee(
          name: result.name,
          phone: result.phone,
          position: result.position,
          isActive: result.isActive,
        );
      }
      showAppSnackBar(
        isEditing
            ? 'Karyawan berhasil diperbarui.'
            : 'Karyawan berhasil ditambahkan.',
      );
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }
}

class _EmployeeInput {
  const _EmployeeInput({
    required this.name,
    required this.phone,
    required this.position,
    required this.isActive,
  });

  final String name;
  final String phone;
  final String position;
  final bool isActive;
}
