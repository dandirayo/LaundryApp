import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import '../../auth/domain/user_role.dart';
import '../../auth/presentation/auth_controller.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      previewDataProvider.select(
        (state) => (customers: state.customers, orders: state.orders),
      ),
    );
    final role = ref.watch(authControllerProvider).value?.user?.role;
    final canImportContacts = role == UserRole.owner;
    final canEditCustomers = role == UserRole.owner;
    final customers = data.customers.where((customer) {
      final text = '${customer.name} ${customer.phone} ${customer.address}'
          .toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          if (canImportContacts)
            IconButton(
              tooltip: 'Import kontak HP',
              onPressed: () => _importContact(context),
              icon: const Icon(Icons.contacts_outlined),
            ),
          IconButton(
            tooltip: 'Tambah pelanggan',
            onPressed: () => _showCustomerDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: customers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showCustomerDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Pelanggan'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, customers.isEmpty ? 24 : 96),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama, telepon, atau alamat',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: customers.isEmpty
                  ? AppStateView.empty(
                      title: 'Pelanggan belum ada',
                      message:
                          'Tambahkan pelanggan agar pesanan bisa memakai customerId yang valid.',
                      actionLabel: 'Tambah pelanggan',
                      onAction: () => _showCustomerDialog(context),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {},
                      child: ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: customers.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          final orders = data.orders
                              .where((order) => order.customerId == customer.id)
                              .toList();
                          final totalKg = orders.fold<double>(
                            0,
                            (sum, order) => sum + order.totalQuantity,
                          );
                          return Card(
                            child: ListTile(
                              minTileHeight: 84,
                              onTap: canEditCustomers
                                  ? () => _showCustomerDialog(
                                      context,
                                      customer: customer,
                                    )
                                  : null,
                              leading: CircleAvatar(
                                backgroundColor: AppColors.softMint,
                                child: Text(
                                  customer.name.characters.first.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryNavy,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${customer.phone}\n${customer.address.isEmpty ? 'Alamat belum diisi' : customer.address}\n${orders.length} kunjungan - ${totalKg.toStringAsFixed(1)} kg',
                              ),
                              isThreeLine: true,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (canEditCustomers)
                                    IconButton(
                                      tooltip: 'Edit pelanggan',
                                      onPressed: () => _showCustomerDialog(
                                        context,
                                        customer: customer,
                                      ),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                  IconButton(
                                    tooltip: 'Telepon',
                                    onPressed: () => _showSnack(
                                      'Aksi telepon siap dihubungkan ke url_launcher.',
                                    ),
                                    icon: const Icon(Icons.call_outlined),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCustomerDialog(
    BuildContext context, {
    PreviewCustomer? customer,
  }) async {
    final isEditing = customer != null;
    final nameController = TextEditingController(text: customer?.name ?? '');
    final phoneController = TextEditingController(text: customer?.phone ?? '');
    final addressController = TextEditingController(
      text: customer?.address ?? '',
    );
    final noteController = TextEditingController(text: customer?.note ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showAppModalBottomSheet<_CustomerInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Form(
          key: formKey,
          child: AppBottomSheetBody(
            children: [
              Text(
                isEditing ? 'Edit Pelanggan' : 'Tambah Pelanggan',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Nomor telepon'),
                validator: (value) => (value ?? '').trim().length < 8
                    ? 'Nomor telepon belum valid.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(labelText: 'Catatan'),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  if (!formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(
                    _CustomerInput(
                      name: nameController.text,
                      phone: phoneController.text,
                      address: addressController.text,
                      note: noteController.text,
                    ),
                  );
                },
                icon: Icon(
                  isEditing ? Icons.check_circle_outline : Icons.save_outlined,
                ),
                label: Text(isEditing ? 'Simpan Perubahan' : 'Simpan'),
              ),
            ],
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    noteController.dispose();

    if (result == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      final notifier = ref.read(previewDataProvider.notifier);
      if (isEditing) {
        notifier.updateCustomer(
          id: customer.id,
          name: result.name,
          phone: result.phone,
          address: result.address,
          note: result.note,
        );
      } else {
        notifier.addCustomer(
          name: result.name,
          phone: result.phone,
          address: result.address,
          note: result.note,
        );
      }
      if (mounted) {
        _showSnack(
          isEditing
              ? 'Pelanggan berhasil diperbarui.'
              : 'Pelanggan berhasil ditambahkan.',
        );
      }
    } on StateError catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<void> _importContact(BuildContext context) async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (!context.mounted) {
      return;
    }
    if (permission != PermissionStatus.granted) {
      _showSnack('Izin kontak belum diberikan.');
      return;
    }

    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    if (!context.mounted) {
      return;
    }
    final candidates =
        contacts
            .where(
              (contact) =>
                  (contact.displayName ?? '').trim().isNotEmpty &&
                  contact.phones.any((phone) => phone.number.trim().isNotEmpty),
            )
            .map(
              (contact) => _ImportedContact(
                name: (contact.displayName ?? '').trim(),
                phone:
                    (contact.phones
                            .firstWhere(
                              (phone) => phone.number.trim().isNotEmpty,
                            )
                            .number)
                        .trim(),
              ),
            )
            .toList()
          ..sort((first, second) => first.name.compareTo(second.name));

    if (candidates.isEmpty) {
      _showSnack('Kontak dengan nomor telepon tidak ditemukan.');
      return;
    }

    final selected = await _showContactPicker(context, candidates);
    if (selected == null || !mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!mounted) {
      return;
    }
    try {
      ref
          .read(previewDataProvider.notifier)
          .addCustomer(
            name: selected.name,
            phone: selected.phone,
            address: '',
            note: 'Import kontak HP',
          );
      if (mounted) {
        _showSnack('${selected.name} berhasil diimport.');
      }
    } on StateError catch (error) {
      if (mounted) {
        _showSnack(error.message);
      }
    }
  }

  Future<_ImportedContact?> _showContactPicker(
    BuildContext context,
    List<_ImportedContact> contacts,
  ) {
    var query = '';
    return showAppModalBottomSheet<_ImportedContact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = contacts.where((contact) {
              final text = '${contact.name} ${contact.phone}'.toLowerCase();
              return text.contains(query.toLowerCase());
            }).toList();

            return AppBottomSheetBody(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Import Kontak HP',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Cari nama atau nomor',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setModalState(() => query = value),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 420,
                  child: filtered.isEmpty
                      ? const Center(child: Text('Kontak tidak ditemukan.'))
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final contact = filtered[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const CircleAvatar(
                                child: Icon(Icons.person_outline),
                              ),
                              title: Text(contact.name),
                              subtitle: Text(contact.phone),
                              onTap: () => Navigator.of(context).pop(contact),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message) {
    showAppSnackBar(message);
  }
}

class _CustomerInput {
  const _CustomerInput({
    required this.name,
    required this.phone,
    required this.address,
    required this.note,
  });

  final String name;
  final String phone;
  final String address;
  final String note;
}

class _ImportedContact {
  const _ImportedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}
