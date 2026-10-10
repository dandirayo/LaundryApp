import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_time_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ui_action_queue.dart';
import '../../../core/widgets/app_bottom_sheet_body.dart';
import '../../../core/widgets/app_snack_bar.dart';
import '../../../core/widgets/responsive_page.dart';
import '../../../shared/preview_data.dart';
import 'inventory_controller.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  static const _quickItems = <(String, String)>[
    ('Gas', 'tabung'),
    ('Plastik 30', 'pak'),
    ('Plastik 35', 'pak'),
    ('Plastik 40', 'pak'),
    ('Plastik 45', 'pak'),
    ('Plastik 50', 'pak'),
    ('Plastik 55', 'pak'),
    ('Sabun', 'liter'),
    ('Pewangi', 'liter'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(
      previewDataProvider.select(
        (state) =>
            (inventory: state.inventory, movements: state.inventoryMovements),
      ),
    );
    final online = ref.watch(inventoryControllerProvider);
    final data = (
      inventory: online.value?.items ?? preview.inventory,
      movements: online.value?.movements ?? preview.movements,
    );
    final missingQuickItems = _quickItems
        .where(
          (preset) => !data.inventory.any(
            (item) => item.name.trim().toLowerCase() == preset.$1.toLowerCase(),
          ),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok & Pengadaan'),
        actions: [
          IconButton(
            tooltip: 'Tambah barang',
            onPressed: () => _showItemSheet(context, ref),
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
      floatingActionButton: data.inventory.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showItemSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Barang'),
            ),
      body: ResponsivePage(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          data.inventory.isEmpty ? 24 : 96,
        ),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (missingQuickItems.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Siapkan barang Live Stock',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Pilih barang yang dipakai. Stok awal dibuat 0; isi jumlah sebenarnya setelah menghitung stok fisik.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _addAllQuickItems(context, ref, missingQuickItems),
                        icon: const Icon(Icons.playlist_add),
                        label: Text(
                          'Tambahkan ${missingQuickItems.length} barang yang belum ada',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final preset in missingQuickItems)
                            ActionChip(
                              avatar: const Icon(Icons.add, size: 17),
                              label: Text(preset.$1),
                              onPressed: () =>
                                  _addQuickItem(context, ref, preset),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (data.inventory.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Belum ada barang. Pilih daftar cepat di atas atau tambah barang sendiri.',
                  ),
                ),
              ),
            for (final item in data.inventory) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (item.isLowStock)
                            const _StockBadge(label: 'Menipis'),
                          if (online.value?.isOnline == true)
                            IconButton(
                              tooltip: 'Edit barang ${item.name}',
                              onPressed: () =>
                                  _showEditItemSheet(context, ref, item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${item.stock.toStringAsFixed(1)} ${item.unit} - Minimum ${item.minStock.toStringAsFixed(1)} ${item.unit}',
                        style: const TextStyle(color: AppColors.secondaryText),
                      ),
                      if (item.note.isNotEmpty) Text(item.note),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _showAdjustSheet(
                              context,
                              ref,
                              item,
                              isAdd: true,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Stok Masuk'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _showAdjustSheet(
                              context,
                              ref,
                              item,
                              isAdd: false,
                            ),
                            icon: const Icon(Icons.remove),
                            label: const Text('Stok Keluar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (data.movements.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Riwayat Stok',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              for (final movement in data.movements.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: Text('${movement.type} ${movement.itemName}'),
                  subtitle: Text(
                    '${movement.quantity.toStringAsFixed(1)} - ${movement.createdAt.toIndonesianDate()} ${movement.createdAt.toIndonesianTime()}',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _addQuickItem(
    BuildContext context,
    WidgetRef ref,
    (String, String) preset,
  ) async {
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .addItem(
            name: preset.$1,
            stock: 0,
            unit: preset.$2,
            minStock: 0,
            purchasePrice: 0,
            note: 'Isi stok awal setelah opname fisik.',
          );
      if (context.mounted) {
        showAppSnackBar(
          '${preset.$1} ditambahkan. Isi stok awal lewat Stok Masuk.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(
          'Barang belum tersimpan. Periksa apakah sudah ada dan coba lagi.',
        );
      }
    }
  }

  Future<void> _addAllQuickItems(
    BuildContext context,
    WidgetRef ref,
    List<(String, String)> missing,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Siapkan daftar barang?'),
        content: Text(
          '${missing.length} barang akan ditambahkan dengan stok 0. '
          'Setelahnya isi jumlah fisik lewat Stok Masuk. Barang yang sudah ada tidak ditambah lagi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Tambahkan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    var added = 0;
    for (final preset in missing) {
      try {
        await ref
            .read(inventoryControllerProvider.notifier)
            .addItem(
              name: preset.$1,
              stock: 0,
              unit: preset.$2,
              minStock: 0,
              purchasePrice: 0,
              note: 'Isi stok awal setelah opname fisik.',
            );
        added++;
      } catch (_) {
        // A previously added item remains saved. Report partial completion.
        break;
      }
    }
    if (context.mounted) {
      showAppSnackBar(
        added == missing.length
            ? '$added barang siap. Isi jumlah stok fisik di tiap barang.'
            : '$added dari ${missing.length} barang tersimpan. Periksa daftar lalu coba lagi.',
      );
    }
  }

  Future<void> _showItemSheet(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final stock = TextEditingController(text: '0');
    final unit = TextEditingController(text: 'liter');
    final minStock = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_InventoryItemInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            const Text(
              'Tambah Barang',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama barang'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stok awal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: unit,
                    decoration: const InputDecoration(labelText: 'Satuan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: minStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Stok minimum'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Harga beli'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(
                  _InventoryItemInput(
                    name: name.text,
                    stock: double.tryParse(stock.text) ?? 0,
                    unit: unit.text,
                    minStock: double.tryParse(minStock.text) ?? 0,
                    purchasePrice: int.tryParse(price.text) ?? 0,
                    note: note.text,
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
    name.dispose();
    stock.dispose();
    unit.dispose();
    minStock.dispose();
    price.dispose();
    note.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    await ref
        .read(inventoryControllerProvider.notifier)
        .addItem(
          name: result.name,
          stock: result.stock,
          unit: result.unit,
          minStock: result.minStock,
          purchasePrice: result.purchasePrice,
          note: result.note,
        );
    showAppSnackBar('Barang stok berhasil ditambahkan.');
  }

  Future<void> _showEditItemSheet(
    BuildContext context,
    WidgetRef ref,
    PreviewInventoryItem item,
  ) async {
    final name = TextEditingController(text: item.name);
    final unit = TextEditingController(text: item.unit);
    final minStock = TextEditingController(text: item.minStock.toString());
    final price = TextEditingController(text: item.purchasePrice.toString());
    final note = TextEditingController(text: item.note);
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_InventoryItemInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            const Text(
              'Edit Barang Live Stock',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'Jumlah stok diubah terpisah lewat Stok Masuk/Keluar agar riwayatnya tercatat.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Nama barang'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Nama barang wajib diisi.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: unit,
              decoration: const InputDecoration(
                labelText: 'Satuan (pak, liter, tabung)',
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Satuan wajib diisi.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: minStock,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Batas stok menipis',
              ),
              validator: (value) => (double.tryParse(value ?? '') ?? -1) < 0
                  ? 'Masukkan angka 0 atau lebih.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Harga beli per satuan',
              ),
              validator: (value) => (int.tryParse(value ?? '') ?? -1) < 0
                  ? 'Masukkan nominal 0 atau lebih.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  sheetContext,
                  _InventoryItemInput(
                    name: name.text.trim(),
                    stock: item.stock,
                    unit: unit.text.trim(),
                    minStock: double.parse(minStock.text),
                    purchasePrice: int.parse(price.text),
                    note: note.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Simpan Barang'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    unit.dispose();
    minStock.dispose();
    price.dispose();
    note.dispose();
    if (result == null || !context.mounted) return;
    await waitForTransientUiDismissal();
    if (!context.mounted) return;
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .updateItem(
            itemId: item.id,
            name: result.name,
            unit: result.unit,
            minStock: result.minStock,
            purchasePrice: result.purchasePrice,
            note: result.note,
          );
      showAppSnackBar('Data barang berhasil diperbarui.');
    } catch (_) {
      showAppSnackBar(
        'Barang belum dapat diperbarui. Periksa nama dan coba lagi.',
      );
    }
  }

  Future<void> _showAdjustSheet(
    BuildContext context,
    WidgetRef ref,
    PreviewInventoryItem item, {
    required bool isAdd,
  }) async {
    final quantity = TextEditingController(text: '1');
    final note = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final result = await showAppModalBottomSheet<_StockAdjustmentInput>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Form(
        key: formKey,
        child: AppBottomSheetBody(
          children: [
            Text(
              '${isAdd ? 'Stok Masuk' : 'Stok Keluar'} ${item.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: quantity,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Jumlah (${item.unit})'),
              validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                  ? 'Jumlah wajib lebih dari nol.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: note,
              decoration: const InputDecoration(labelText: 'Catatan'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(
                  _StockAdjustmentInput(
                    quantity: double.parse(quantity.text),
                    type: isAdd ? 'IN' : 'OUT',
                    note: note.text,
                  ),
                );
              },
              icon: Icon(isAdd ? Icons.add : Icons.remove),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    quantity.dispose();
    note.dispose();

    if (result == null || !context.mounted) {
      return;
    }
    await waitForTransientUiDismissal();
    if (!context.mounted) {
      return;
    }
    try {
      await ref
          .read(inventoryControllerProvider.notifier)
          .adjust(
            itemId: item.id,
            quantity: result.quantity,
            type: result.type,
            note: result.note,
          );
      showAppSnackBar('Riwayat stok tersimpan.');
    } on StateError catch (error) {
      showAppSnackBar(error.message);
    }
  }
}

class _InventoryItemInput {
  const _InventoryItemInput({
    required this.name,
    required this.stock,
    required this.unit,
    required this.minStock,
    required this.purchasePrice,
    required this.note,
  });

  final String name;
  final double stock;
  final String unit;
  final double minStock;
  final int purchasePrice;
  final String note;
}

class _StockAdjustmentInput {
  const _StockAdjustmentInput({
    required this.quantity,
    required this.type,
    required this.note,
  });

  final double quantity;
  final String type;
  final String note;
}

class _StockBadge extends StatelessWidget {
  const _StockBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.warning,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
