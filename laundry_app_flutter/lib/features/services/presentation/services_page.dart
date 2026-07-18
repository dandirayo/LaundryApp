import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  static const _categories = [
    'Cuci Setrika',
    'Setrika',
    'Sepatu',
    'Helm',
    'Satuan',
    'Layanan Tambahan',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(previewDataProvider).services;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Layanan & Harga'),
        actions: [
          IconButton(
            tooltip: 'Tambah layanan',
            onPressed: () => _showServiceDialog(context, ref),
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showServiceDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Layanan'),
      ),
      body: ResponsivePage(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        child: services.isEmpty
            ? AppStateView.empty(
                title: 'Layanan belum ada',
                message:
                    'Tambahkan layanan agar flow pesanan bisa menghitung harga.',
                actionLabel: 'Tambah layanan',
                onAction: () => _showServiceDialog(context, ref),
              )
            : ListView.separated(
                itemCount: services.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return Card(
                    child: ListTile(
                      minTileHeight: 82,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: service.isExpress
                              ? AppColors.warning.withValues(alpha: 0.14)
                              : AppColors.softMint,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          service.isExpress
                              ? Icons.flash_on_outlined
                              : Icons.local_laundry_service_outlined,
                          color: service.isExpress
                              ? AppColors.warning
                              : AppColors.primaryNavy,
                        ),
                      ),
                      title: Text(
                        service.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${service.category} - ${service.unit} - ${service.estimatedHours} jam',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.price.toRupiah(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                          Text(
                            service.isActive ? 'Aktif' : 'Nonaktif',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
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

  Future<void> _showServiceDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    final hoursController = TextEditingController(text: '48');
    final formKey = GlobalKey<FormState>();
    var category = _categories.first;
    var isExpress = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      'Tambah Layanan',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama layanan',
                      ),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Nama layanan wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      items: [
                        for (final item in _categories)
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) =>
                          setModalState(() => category = value ?? category),
                      decoration: const InputDecoration(labelText: 'Kategori'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Harga',
                            ),
                            validator: (value) =>
                                (int.tryParse(value ?? '') ?? 0) <= 0
                                ? 'Harga wajib lebih dari nol.'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'Satuan',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: hoursController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimasi selesai (jam)',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Express'),
                      value: isExpress,
                      onChanged: (value) =>
                          setModalState(() => isExpress = value),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) {
                          return;
                        }
                        ref
                            .read(previewDataProvider.notifier)
                            .addService(
                              name: nameController.text,
                              category: category,
                              unit: unitController.text.trim().isEmpty
                                  ? 'kg'
                                  : unitController.text.trim(),
                              price: int.parse(priceController.text),
                              estimatedHours:
                                  int.tryParse(hoursController.text) ?? 48,
                              isExpress: isExpress,
                            );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Layanan berhasil ditambahkan.'),
                          ),
                        );
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
      },
    );
    nameController.dispose();
    priceController.dispose();
    unitController.dispose();
    hoursController.dispose();
  }
}
