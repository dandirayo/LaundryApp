import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/responsive_page.dart';
import 'auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value?.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text((user?.name ?? 'P').characters.first),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Pengguna',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(user?.role.label ?? '-'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileTile(label: 'User ID', value: user?.userId ?? '-'),
            _ProfileTile(label: 'Shop ID', value: user?.shopId ?? '-'),
            _ProfileTile(label: 'Employee ID', value: user?.employeeId ?? '-'),
            _ProfileTile(label: 'Telepon', value: user?.phone ?? '-'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: user == null
                  ? null
                  : () => _showEditProfileSheet(
                      context,
                      ref,
                      user.name,
                      user.phone ?? '',
                    ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Profil'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String currentName,
    String currentPhone,
  ) async {
    final name = TextEditingController(text: currentName);
    final phone = TextEditingController(text: currentPhone);
    final formKey = GlobalKey<FormState>();
    final result = await showModalBottomSheet<_ProfileInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            const Text(
              'Edit Profil',
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
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Nomor telepon'),
              validator: (value) => (value ?? '').trim().length < 8
                  ? 'Nomor telepon belum valid.'
                  : null,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(
                  context,
                ).pop(_ProfileInput(name: name.text, phone: phone.text));
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Profil'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    phone.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await ref
        .read(authControllerProvider.notifier)
        .updateProfile(name: result.name, phone: result.phone);
    if (!context.mounted) {
      return;
    }
    final error = ref.read(authControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Profil tersimpan.'
              : error is Failure
              ? error.message
              : 'Profil gagal disimpan.',
        ),
      ),
    );
  }
}

class _ProfileInput {
  const _ProfileInput({required this.name, required this.phone});

  final String name;
  final String phone;
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(title: Text(label), subtitle: Text(value)),
    );
  }
}
