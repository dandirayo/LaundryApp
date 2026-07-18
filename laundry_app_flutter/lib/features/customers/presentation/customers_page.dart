import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(previewDataProvider);
    final customers = data.customers.where((customer) {
      final text = '${customer.name} ${customer.phone} ${customer.address}'
          .toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        actions: [
          IconButton(
            tooltip: 'Tambah pelanggan',
            onPressed: () => _showCustomerDialog(context),
            icon: const Icon(Icons.person_add_alt_1),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCustomerDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Pelanggan'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                              trailing: IconButton(
                                tooltip: 'Telepon',
                                onPressed: () => _showSnack(
                                  'Aksi telepon siap dihubungkan ke url_launcher.',
                                ),
                                icon: const Icon(Icons.call_outlined),
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

  Future<void> _showCustomerDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tambah Pelanggan',
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
                    try {
                      ref
                          .read(previewDataProvider.notifier)
                          .addCustomer(
                            name: nameController.text,
                            phone: phoneController.text,
                            address: addressController.text,
                            note: noteController.text,
                          );
                      Navigator.of(context).pop();
                      _showSnack('Pelanggan berhasil ditambahkan.');
                    } on StateError catch (error) {
                      _showSnack(error.message);
                    }
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Simpan'),
                ),
              ],
            ),
          ),
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    noteController.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
