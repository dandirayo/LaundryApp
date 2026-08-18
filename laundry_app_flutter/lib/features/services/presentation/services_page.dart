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
import 'service_controller.dart';

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
    final previewServices = ref.watch(
      previewDataProvider.select((state) => state.services),
    );
    final services =
        ref.watch(serviceControllerProvider).value ?? previewServices;
    final groupedServices = _groupServices(services);
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
                itemCount: groupedServices.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groupedServices[index];
                  final expansionTheme = Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                    expansionTileTheme: const ExpansionTileThemeData(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.transparent),
                      ),
                      collapsedShape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.transparent),
                      ),
                    ),
                  );
                  return Theme(
                    data: expansionTheme,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ExpansionTile(
                        initiallyExpanded: index < 3,
                        leading: const Icon(Icons.category_outlined),
                        title: Text(
                          group.category,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: Text(
                          strings.isEnglish
                              ? '${group.services.length} price variants'
                              : '${group.services.length} varian harga',
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          12,
                          0,
                          12,
                          12,
                        ),
                        children: [
                          for (final itemGroup in group.items)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(
                                left: 8,
                                bottom: 8,
                              ),
                              title: Text(
                                itemGroup.itemName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${itemGroup.services.length} pilihan',
                              ),
                              children: [
                                for (final service in itemGroup.services)
                                  ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      service.isExpress
                                          ? Icons.flash_on_outlined
                                          : Icons
                                                .local_laundry_service_outlined,
                                      color: service.isExpress
                                          ? AppColors.warning
                                          : AppColors.primaryBlue,
                                    ),
                                    title: Text(
                                      service.effectiveVariant.isEmpty
                                          ? service.name
                                          : service.effectiveVariant,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${service.unit} · ${service.estimatedHours} jam',
                                    ),
                                    trailing: Text(
                                      service.price.toRupiah(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primaryNavy,
                                      ),
                                    ),
                                  ),
                              ],
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

  List<_ServiceCategoryGroup> _groupServices(List<PreviewService> services) {
    final sorted = [...services]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final groups = <String, List<PreviewService>>{};
    for (final service in sorted) {
      groups
          .putIfAbsent(service.effectiveCategory, () => <PreviewService>[])
          .add(service);
    }
    return [
      for (final entry in groups.entries)
        _ServiceCategoryGroup(category: entry.key, services: entry.value),
    ];
  }

  Future<void> _showServiceDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final itemController = TextEditingController();
    final sizeController = TextEditingController();
    final materialController = TextEditingController();
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
                  TextFormField(
                    controller: itemController,
                    decoration: InputDecoration(
                      labelText: strings.isEnglish ? 'Item name' : 'Nama item',
                      helperText: strings.isEnglish
                          ? 'Example: T-shirt, Sheet, Bed Cover'
                          : 'Contoh: Kaos, Sprei, Bed Cover',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: sizeController,
                          decoration: InputDecoration(
                            labelText: strings.isEnglish ? 'Size' : 'Ukuran',
                            helperText: 'S/M/L, Sedang, Besar',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: materialController,
                          decoration: InputDecoration(
                            labelText: strings.isEnglish
                                ? 'Material / quality'
                                : 'Bahan / kualitas',
                            helperText: 'Normal, Bagus, Katun',
                          ),
                        ),
                      ),
                    ],
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
                          itemName: itemController.text,
                          sizeVariant: sizeController.text,
                          materialVariant: materialController.text,
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
    itemController.dispose();
    sizeController.dispose();
    materialController.dispose();
    priceController.dispose();
    hoursController.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    await ref
        .read(serviceControllerProvider.notifier)
        .add(
          name: result.name,
          itemName: result.itemName,
          sizeVariant: result.sizeVariant,
          materialVariant: result.materialVariant,
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
    required this.itemName,
    required this.sizeVariant,
    required this.materialVariant,
    required this.category,
    required this.unit,
    required this.price,
    required this.estimatedHours,
    required this.isExpress,
  });

  final String name;
  final String itemName;
  final String sizeVariant;
  final String materialVariant;
  final String category;
  final String unit;
  final int price;
  final int estimatedHours;
  final bool isExpress;
}

class _ServiceCategoryGroup {
  _ServiceCategoryGroup({required this.category, required this.services});

  final String category;
  final List<PreviewService> services;

  List<_ServiceItemGroup> get items {
    final groups = <String, List<PreviewService>>{};
    for (final service in services) {
      groups
          .putIfAbsent(service.effectiveItem, () => <PreviewService>[])
          .add(service);
    }
    return [
      for (final entry in groups.entries)
        _ServiceItemGroup(itemName: entry.key, services: entry.value),
    ];
  }
}

class _ServiceItemGroup {
  const _ServiceItemGroup({required this.itemName, required this.services});

  final String itemName;
  final List<PreviewService> services;
}
