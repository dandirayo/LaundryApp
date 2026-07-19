import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/currency_extensions.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';

class ServicesPage extends ConsumerWidget {
  const ServicesPage({super.key});

  static const _categories = [
    'Cuci Setrika',
    'Cuci Lipat',
    'Setrika Lipat',
    'Pakaian',
    'Alat Tidur',
    'Perlengkapan Rumah',
    'Tas',
    'Perlengkapan Ibadah',
    'Lainnya',
    'Sepatu',
    'Helm',
    'Layanan Tambahan',
  ];

  static const _units = ['KG', 'ITEM', 'PAIR', 'PIECE', 'SET'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(
      previewDataProvider.select((state) => state.services),
    );
    final strings = ref.strings;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.servicesAndPrices),
        actions: [
          IconButton(
            tooltip: strings.isEnglish ? 'Add service' : 'Tambah layanan',
            onPressed: () => _showServiceDialog(context, ref),
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      floatingActionButton: services.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showServiceDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(strings.service),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(16, 8, 16, services.isEmpty ? 24 : 96),
        child: services.isEmpty
            ? AppStateView.empty(
                title: strings.isEnglish
                    ? 'No services yet'
                    : 'Layanan belum ada',
                message: strings.isEnglish
                    ? 'Add services so the order flow can calculate prices.'
                    : 'Tambahkan layanan agar flow pesanan bisa menghitung harga.',
                actionLabel: strings.isEnglish
                    ? 'Add service'
                    : 'Tambah layanan',
                onAction: () => _showServiceDialog(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 24),
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
                        '${service.breadcrumb} - ${service.unit} - ${service.estimatedHours} jam',
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
                            service.isActive
                                ? (strings.isEnglish ? 'Active' : 'Aktif')
                                : (strings.isEnglish ? 'Inactive' : 'Nonaktif'),
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
    final hoursController = TextEditingController(text: '48');
    final formKey = GlobalKey<FormState>();
    final strings = ref.read(appLanguageProvider) == AppLanguage.en
        ? const AppStrings(AppLanguage.en)
        : const AppStrings(AppLanguage.id);
    var category = _categories.first;
    var unit = _units.first;
    var isExpress = false;

    final result = await showAppModalBottomSheet<_ServiceInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Form(
              key: formKey,
              child: AppBottomSheetBody(
                children: [
                  Text(
                    strings.isEnglish ? 'Add Service' : 'Tambah Layanan',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: strings.isEnglish
                          ? 'Service name'
                          : 'Nama layanan',
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? (strings.isEnglish
                              ? 'Service name is required.'
                              : 'Nama layanan wajib diisi.')
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
                    decoration: InputDecoration(
                      labelText: strings.isEnglish ? 'Category' : 'Kategori',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: strings.isEnglish ? 'Price' : 'Harga',
                          ),
                          validator: (value) =>
                              (int.tryParse(value ?? '') ?? 0) <= 0
                              ? (strings.isEnglish
                                    ? 'Price must be greater than zero.'
                                    : 'Harga wajib lebih dari nol.')
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: unit,
                          items: [
                            for (final item in _units)
                              DropdownMenuItem(value: item, child: Text(item)),
                          ],
                          onChanged: (value) =>
                              setModalState(() => unit = value ?? unit),
                          decoration: InputDecoration(
                            labelText: strings.isEnglish ? 'Unit' : 'Satuan',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: hoursController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: strings.isEnglish
                          ? 'Estimated completion (hours)'
                          : 'Estimasi selesai (jam)',
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
                      Navigator.of(context).pop(
                        _ServiceInput(
                          name: nameController.text,
                          category: category,
                          unit: unit,
                          price: int.parse(priceController.text),
                          estimatedHours:
                              int.tryParse(hoursController.text) ?? 48,
                          isExpress: isExpress,
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: Text(strings.save),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
    priceController.dispose();
    hoursController.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    ref
        .read(previewDataProvider.notifier)
        .addService(
          name: result.name,
          category: result.category,
          unit: result.unit,
          price: result.price,
          estimatedHours: result.estimatedHours,
          isExpress: result.isExpress,
        );
    showAppSnackBar(
      strings.isEnglish
          ? 'Service added successfully.'
          : 'Layanan berhasil ditambahkan.',
    );
  }
}

class _ServiceInput {
  const _ServiceInput({
    required this.name,
    required this.category,
    required this.unit,
    required this.price,
    required this.estimatedHours,
    required this.isExpress,
  });

  final String name;
  final String category;
  final String unit;
  final int price;
  final int estimatedHours;
  final bool isExpress;
}
