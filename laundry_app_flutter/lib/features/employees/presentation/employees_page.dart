import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_bottom_sheet_body.dart';
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
            onPressed: () => _showEmployeeSheet(context, ref),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: employees.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showEmployeeSheet(context, ref),
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
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(employee.name),
                      subtitle: Text(
                        '${employee.position} - ${employee.phone}',
                      ),
                      trailing: Text(employee.isActive ? 'Aktif' : 'Nonaktif'),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showEmployeeSheet(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final position = TextEditingController(text: 'Operator');
    final formKey = GlobalKey<FormState>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            const Text(
              'Tambah Karyawan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
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
              decoration: const InputDecoration(labelText: 'Telepon'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: position,
              decoration: const InputDecoration(labelText: 'Posisi'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                ref
                    .read(previewDataProvider.notifier)
                    .addEmployee(
                      name: name.text,
                      phone: phone.text,
                      position: position.text,
                    );
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    position.dispose();
  }
}
