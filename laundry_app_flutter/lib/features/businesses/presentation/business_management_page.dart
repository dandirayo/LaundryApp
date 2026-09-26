import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/user_error_message.dart';
import '../../../core/router/app_navigation.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../domain/business.dart';
import 'business_controller.dart';

class BusinessManagementPage extends ConsumerWidget {
  const BusinessManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(businessControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Usaha'),
        leading: IconButton(
          onPressed: () =>
              AppNavigation.back(context, fallback: AppRoutes.businessSelector),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBusiness(context, ref),
        icon: const Icon(Icons.add_business),
        label: const Text('Tambah Usaha'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppStateView.error(
            title: 'Data usaha gagal dimuat',
            message: '$error',
            actionLabel: 'Coba lagi',
            onAction: () =>
                ref.read(businessControllerProvider.notifier).refresh(),
          ),
          data: (data) => ListView.separated(
            itemCount: data.businesses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final business = data.businesses[index];
              final assigned = data.assignments[business.id]?.length ?? 0;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            business.kind == BusinessKind.laundry
                                ? Icons.local_laundry_service_outlined
                                : Icons.local_cafe_outlined,
                            color: AppColors.primaryBlue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  business.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  '${business.kind.label} · $assigned karyawan',
                                  style: const TextStyle(
                                    color: AppColors.secondaryText,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: business.isActive,
                            onChanged: (value) =>
                                _setActive(context, ref, business, value),
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () =>
                              _showAssignments(context, ref, business, data),
                          icon: const Icon(Icons.group_add_outlined, size: 19),
                          label: const Text('Atur Karyawan'),
                        ),
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

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    Business business,
    bool value,
  ) async {
    try {
      await ref
          .read(businessControllerProvider.notifier)
          .setBusinessActive(business, value);
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(error, fallback: 'Status usaha gagal diperbarui.'),
        );
      }
    }
  }

  Future<void> _showAddBusiness(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(text: 'Es Teh Manis');
    final formKey = GlobalKey<FormState>();
    final submitted = await showAppModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            const Text(
              'Tambah Usaha POS',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text(
              'Usaha baru memakai POS minuman sederhana. Modul Laundry tetap memakai usaha Laundry utama.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama usaha'),
              validator: (value) => (value ?? '').trim().length < 2
                  ? 'Nama usaha minimal 2 karakter.'
                  : null,
            ),
            const SizedBox(height: 12),
            const InputDecorator(
              decoration: InputDecoration(labelText: 'Tipe usaha'),
              child: Text('POS Minuman'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.of(context).pop(true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Usaha'),
            ),
          ],
        ),
      ),
    );
    final value = name.text.trim();
    name.dispose();
    if (submitted != true || !context.mounted) return;
    try {
      await ref
          .read(businessControllerProvider.notifier)
          .createBusiness(name: value, kind: BusinessKind.beverage);
      if (context.mounted) {
        showAppSnackBar('Usaha $value berhasil ditambahkan.');
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnackBar(
          userErrorMessage(
            error,
            fallback:
                'Usaha gagal ditambahkan. Pastikan namanya belum dipakai.',
          ),
        );
      }
    }
  }

  Future<void> _showAssignments(
    BuildContext context,
    WidgetRef ref,
    Business business,
    BusinessState data,
  ) async {
    final selected = {...?data.assignments[business.id]};
    await showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheetBody(
          children: [
            Text(
              'Karyawan ${business.name}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 6),
            const Text('Pilih karyawan yang boleh membuka usaha ini.'),
            const SizedBox(height: 12),
            if (data.assignees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text('Belum ada akun karyawan aktif.'),
              )
            else
              for (final employee in data.assignees)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(employee.profileId),
                  title: Text(employee.name),
                  subtitle: const Text('Karyawan'),
                  onChanged: (value) async {
                    final assigned = value ?? false;
                    try {
                      await ref
                          .read(businessControllerProvider.notifier)
                          .setAssignment(
                            businessId: business.id,
                            profileId: employee.profileId,
                            assigned: assigned,
                          );
                      setModalState(() {
                        assigned
                            ? selected.add(employee.profileId)
                            : selected.remove(employee.profileId);
                      });
                    } catch (error) {
                      if (context.mounted) {
                        showAppSnackBar(
                          userErrorMessage(
                            error,
                            fallback: 'Penugasan karyawan gagal diperbarui.',
                          ),
                        );
                      }
                    }
                  },
                ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Selesai'),
            ),
          ],
        ),
      ),
    );
  }
}
