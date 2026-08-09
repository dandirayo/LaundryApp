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
      body: RefreshIndicator(
        onRefresh: () => _loadOnlineEmployees(showResult: true),
        child: ResponsivePage(
          padding: EdgeInsets.fromLTRB(16, 8, 16, employees.isEmpty ? 24 : 96),
          child: employees.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 80),
                    AppStateView.empty(
                      title: 'Karyawan belum ada',
                      message:
                          'Tambahkan data karyawan untuk shift dan absensi. Tarik ke bawah untuk refresh data Supabase.',
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
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
                            '${employee.shiftStart}-${employee.shiftEnd}',
                            'Telat maks ${employee.lateToleranceMinutes} menit',
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
    final shiftStart = TextEditingController(
      text: employee?.shiftStart ?? '06.00',
    );
    final shiftEnd = TextEditingController(text: employee?.shiftEnd ?? '14.00');
    final lateTolerance = TextEditingController(
      text: '${employee?.lateToleranceMinutes ?? 120}',
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: shiftStart,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Mulai shift',
                          helperText: 'Contoh 06.00',
                        ),
                        validator: _validateTime,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: shiftEnd,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: 'Selesai shift',
                          helperText: 'Contoh 14.00',
                        ),
                        validator: _validateTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lateTolerance,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Toleransi telat (menit)',
                    helperText: 'Default 120 menit.',
                  ),
                  validator: (value) {
                    final minutes = int.tryParse((value ?? '').trim());
                    if (minutes == null || minutes < 0 || minutes > 480) {
                      return 'Isi 0-480 menit.';
                    }
                    return null;
                  },
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
                        shiftStart: shiftStart.text,
                        shiftEnd: shiftEnd.text,
                        lateToleranceMinutes: int.parse(
                          lateTolerance.text.trim(),
                        ),
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
    shiftStart.dispose();
    shiftEnd.dispose();
    lateTolerance.dispose();
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
            shiftStart: result.shiftStart,
            shiftEnd: result.shiftEnd,
            lateToleranceMinutes: result.lateToleranceMinutes,
            isActive: result.isActive,
          );
          if (!context.mounted) return;
        }
        notifier.updateEmployee(
          id: employee.id,
          name: result.name,
          phone: result.phone,
          position: result.position,
          shiftStart: result.shiftStart,
          shiftEnd: result.shiftEnd,
          lateToleranceMinutes: result.lateToleranceMinutes,
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
            shiftStart: result.shiftStart,
            shiftEnd: result.shiftEnd,
            lateToleranceMinutes: result.lateToleranceMinutes,
            isActive: result.isActive,
          );
          if (!context.mounted) return;
        }
        notifier.addEmployee(
          id: account?.employeeId,
          name: result.name,
          phone: result.phone,
          position: result.position,
          shiftStart: result.shiftStart,
          shiftEnd: result.shiftEnd,
          lateToleranceMinutes: result.lateToleranceMinutes,
          isActive: result.isActive,
          username: account?.username ?? result.username,
        );
        if (isOnline) {
          await _loadOnlineEmployees();
        }
      }
      showAppSnackBar(
        isEditing
            ? 'Karyawan berhasil diperbarui.'
            : 'Karyawan berhasil ditambahkan.',
      );
    } on Failure catch (error) {
      if (context.mounted) {
        await _showSaveErrorDialog(context, error.message);
      }
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    } catch (error) {
      final message = error.toString().contains('404')
          ? 'Fungsi akun karyawan belum dipasang di Supabase.'
          : 'Gagal menyimpan karyawan: $error';
      if (context.mounted) {
        await _showSaveErrorDialog(context, message);
      }
    }
  }

  Future<void> _loadOnlineEmployees({bool showResult = false}) async {
    final repository = EmployeeRepository();
    if (!repository.isOnline) {
      if (showResult) {
        showAppSnackBar('Supabase belum dikonfigurasi.');
      }
      return;
    }
    try {
      final employees = await repository.fetchEmployees();
      if (!mounted) return;
      ref.read(previewDataProvider.notifier).replaceEmployees(employees);
      if (showResult) {
        showAppSnackBar('Data karyawan diperbarui.');
      }
    } catch (error) {
      if (!mounted) return;
      if (showResult) {
        showAppSnackBar('Data karyawan online belum dapat dimuat: $error');
      }
    }
  }

  Future<void> _showSaveErrorDialog(BuildContext context, String message) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Karyawan belum tersimpan'),
        content: Text(
          '$message\n\nKalau ingin karyawan bisa login, pastikan Edge Function create-employee-user sudah dideploy di Supabase dan migration terbaru sudah dijalankan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }

  String? _validateTime(String? value) {
    final text = (value ?? '').trim().replaceAll('.', ':');
    final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(text);
    if (match == null) {
      return 'Format jam belum valid.';
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return 'Format jam belum valid.';
    }
    return null;
  }
}

class _EmployeeInput {
  const _EmployeeInput({
    required this.name,
    required this.phone,
    required this.position,
    required this.shiftStart,
    required this.shiftEnd,
    required this.lateToleranceMinutes,
    required this.isActive,
    required this.username,
    required this.password,
  });

  final String name;
  final String phone;
  final String position;
  final String shiftStart;
  final String shiftEnd;
  final int lateToleranceMinutes;
  final bool isActive;
  final String username;
  final String password;
}
