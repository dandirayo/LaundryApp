import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../data/employee_repository.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});

  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnlineEmployees());
  }

  @override
  Widget build(BuildContext context) {
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
                        [
                          employee.position,
                          employee.phone,
                          if (employee.username.isNotEmpty)
                            '@${employee.username}',
                        ].where((value) => value.isNotEmpty).join(' - '),
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
    final repository = EmployeeRepository();
    final isOnline = repository.isOnline;
    final name = TextEditingController(text: employee?.name ?? '');
    final phone = TextEditingController(text: employee?.phone ?? '');
    final position = TextEditingController(
      text: employee?.position ?? 'Operator',
    );
    final username = TextEditingController(text: employee?.username ?? '');
    final password = TextEditingController();
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
                if (isOnline) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: username,
                    enabled: !isEditing,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      labelText: 'Username login',
                      prefixIcon: const Icon(Icons.alternate_email),
                      helperText: isEditing
                          ? 'Username tidak diubah dari halaman ini.'
                          : 'Contoh: karyawan1',
                    ),
                    validator: (value) {
                      if (isEditing) return null;
                      final text = (value ?? '').trim().toLowerCase();
                      if (!RegExp(r'^[a-z0-9._-]{3,32}$').hasMatch(text)) {
                        return 'Gunakan 3-32 huruf kecil, angka, titik, _ atau -.';
                      }
                      return null;
                    },
                  ),
                  if (!isEditing) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: password,
                      obscureText: true,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Password awal',
                        prefixIcon: Icon(Icons.lock_outline),
                        helperText: 'Minimal 8 karakter.',
                      ),
                      validator: (value) => (value ?? '').length < 8
                          ? 'Password minimal 8 karakter.'
                          : null,
                    ),
                  ],
                ],
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
                        username: username.text,
                        password: password.text,
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
    username.dispose();
    password.dispose();

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
        if (isOnline) {
          await repository.updateEmployee(
            id: employee.id,
            name: result.name,
            phone: result.phone,
            position: result.position,
            isActive: result.isActive,
          );
          if (!context.mounted) return;
        }
        notifier.updateEmployee(
          id: employee.id,
          name: result.name,
          phone: result.phone,
          position: result.position,
          isActive: result.isActive,
        );
      } else {
        CreatedEmployeeAccount? account;
        if (isOnline) {
          account = await repository.createAccount(
            username: result.username,
            password: result.password,
            name: result.name,
            phone: result.phone,
            position: result.position,
          );
          if (!context.mounted) return;
        }
        notifier.addEmployee(
          id: account?.employeeId,
          name: result.name,
          phone: result.phone,
          position: result.position,
          isActive: result.isActive,
          username: account?.username ?? result.username,
        );
      }
      showAppSnackBar(
        isEditing
            ? 'Karyawan berhasil diperbarui.'
            : 'Karyawan berhasil ditambahkan.',
      );
    } on Failure catch (error) {
      showAppSnackBar(error.message);
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    } catch (error) {
      final message = error.toString().contains('404')
          ? 'Fungsi akun karyawan belum dipasang di Supabase.'
          : 'Gagal menyimpan karyawan: $error';
      showAppSnackBar(message);
    }
  }

  Future<void> _loadOnlineEmployees() async {
    final repository = EmployeeRepository();
    if (!repository.isOnline) return;
    try {
      final employees = await repository.fetchEmployees();
      if (!mounted) return;
      ref.read(previewDataProvider.notifier).replaceEmployees(employees);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar('Data karyawan online belum dapat dimuat: $error');
    }
  }
}

class _EmployeeInput {
  const _EmployeeInput({
    required this.name,
    required this.phone,
    required this.position,
    required this.isActive,
    required this.username,
    required this.password,
  });

  final String name;
  final String phone;
  final String position;
  final bool isActive;
  final String username;
  final String password;
}
